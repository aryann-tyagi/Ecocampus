-- EcoCampus Migration: EcoPoints Gamification System
-- Creates a secure, auditable points ledger with server-side award function.
-- Fully aligned with PRD v1.0 §12.1 and §14 baseline scoring rules.

-- ============================================================================
-- 1. eco_point_events — Immutable ledger of all point-earning events.
-- Each row represents a single, verified point award.
-- The (user_id, idempotency_key) unique constraint prevents duplicate awards.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.eco_point_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_type   TEXT NOT NULL,
  points        INTEGER NOT NULL CHECK (points > 0),
  idempotency_key TEXT NOT NULL,
  reference_id  TEXT,       -- e.g. the report_id that triggered this award
  description   TEXT,       -- human-readable description of what earned points
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Prevent awarding the same event twice for the same user
  UNIQUE (user_id, idempotency_key)
);

-- Index for fast per-user queries and leaderboard aggregation
CREATE INDEX IF NOT EXISTS idx_eco_point_events_user
  ON public.eco_point_events(user_id, created_at DESC);

-- Index for leaderboard aggregation across all users
CREATE INDEX IF NOT EXISTS idx_eco_point_events_created
  ON public.eco_point_events(created_at);

-- ============================================================================
-- 2. Row Level Security — Students can only READ their own point events.
-- No INSERT/UPDATE/DELETE allowed directly from client.
-- ============================================================================
ALTER TABLE public.eco_point_events ENABLE ROW LEVEL SECURITY;

-- Grant read-only access to authenticated users
GRANT SELECT ON TABLE public.eco_point_events TO authenticated;

-- Students can only see their own events
DROP POLICY IF EXISTS "Users can view own eco point events" ON public.eco_point_events;
CREATE POLICY "Users can view own eco point events"
  ON public.eco_point_events
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- ============================================================================
-- 3. award_eco_points — Secure server-side RPC to award points.
-- Runs as SECURITY DEFINER so it can INSERT into eco_point_events even though
-- the student's role has no direct INSERT grant on that table.
-- Validates caller, action_type, points, and verifies report existence in public.reports.
-- Returns the points awarded (0 if already awarded = idempotent).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.award_eco_points(
  p_user_id         UUID,
  p_action_type     TEXT,
  p_points          INTEGER,
  p_idempotency_key TEXT,
  p_reference_id    TEXT DEFAULT NULL,
  p_description     TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_valid_actions TEXT[] := ARRAY[
    'report_submitted',
    'report_critical',
    'report_resolved',
    'challenge_completed'
  ];
  v_awarded INTEGER := 0;
  v_report_exists BOOLEAN;
BEGIN
  -- Security check: Caller must be authenticated and matching p_user_id
  IF auth.uid() IS NULL OR auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot award points for another user';
  END IF;

  -- Validate action type
  IF NOT (p_action_type = ANY(v_valid_actions)) THEN
    RAISE EXCEPTION 'Invalid action_type: %', p_action_type;
  END IF;

  -- PRD §12.1 validation: Verify points match approved reward policy
  IF p_action_type = 'report_submitted' AND p_points != 30 THEN
    RAISE EXCEPTION 'Invalid points for report_submitted: expected 30 (PRD §12.1)';
  END IF;

  IF p_action_type = 'report_critical' AND p_points != 50 THEN
    RAISE EXCEPTION 'Invalid points for report_critical: expected 50 (PRD §12.1)';
  END IF;

  IF p_action_type = 'report_resolved' AND p_points != 20 THEN
    RAISE EXCEPTION 'Invalid points for report_resolved: expected 20 (PRD §12.1)';
  END IF;

  IF p_action_type = 'challenge_completed' AND p_points != 100 THEN
    RAISE EXCEPTION 'Invalid points for challenge_completed: expected 100 (PRD §12.1)';
  END IF;

  -- Eligibility verification: When reference_id is provided, verify report belongs to user
  IF p_reference_id IS NOT NULL AND p_action_type IN ('report_submitted', 'report_critical') THEN
    SELECT EXISTS (
      SELECT 1 FROM public.reports
      WHERE id = p_reference_id::UUID
        AND reporter_id = p_user_id
        AND status NOT IN ('REJECTED', 'DUPLICATE')
    ) INTO v_report_exists;

    IF NOT v_report_exists THEN
      RAISE EXCEPTION 'Report % not found or ineligible for user %', p_reference_id, p_user_id;
    END IF;
  END IF;

  -- Attempt insert (ON CONFLICT = idempotent deduplication)
  INSERT INTO public.eco_point_events (
    user_id, action_type, points, idempotency_key, reference_id, description
  )
  VALUES (
    p_user_id, p_action_type, p_points, p_idempotency_key, p_reference_id, p_description
  )
  ON CONFLICT (user_id, idempotency_key) DO NOTHING;

  IF FOUND THEN
    v_awarded := p_points;
  END IF;

  RETURN v_awarded;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.award_eco_points(UUID, TEXT, INTEGER, TEXT, TEXT, TEXT) TO authenticated;

-- ============================================================================
-- 4. get_user_eco_summary — Returns total points and event count for auth.uid().
-- Resilient: aggregates from eco_point_events, or derives from public.reports.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_user_eco_summary()
RETURNS TABLE(total_points BIGINT, event_count BIGINT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pts BIGINT;
  v_cnt BIGINT;
BEGIN
  -- First check ledger table
  SELECT COALESCE(SUM(points), 0)::BIGINT, COUNT(*)::BIGINT
  INTO v_pts, v_cnt
  FROM public.eco_point_events
  WHERE user_id = auth.uid();

  -- If no ledger entries exist, compute verified points from public.reports
  IF v_cnt = 0 THEN
    SELECT
      COALESCE(
        SUM(CASE WHEN severity = 'critical' THEN 50 ELSE 30 END) +
        SUM(CASE WHEN status = 'RESOLVED' THEN 20 ELSE 0 END),
        0
      )::BIGINT,
      COUNT(*)::BIGINT
    INTO v_pts, v_cnt
    FROM public.reports
    WHERE reporter_id = auth.uid()
      AND status NOT IN ('REJECTED', 'DUPLICATE');
  END IF;

  RETURN QUERY SELECT COALESCE(v_pts, 0::BIGINT), COALESCE(v_cnt, 0::BIGINT);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_eco_summary() TO authenticated;

-- ============================================================================
-- 5. get_eco_leaderboard — Returns top N users by total points.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_eco_leaderboard(p_limit INTEGER DEFAULT 10)
RETURNS TABLE(
  user_id UUID,
  display_name TEXT,
  total_points BIGINT,
  rank BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH combined_points AS (
    SELECT
      user_id,
      SUM(points)::BIGINT AS points
    FROM public.eco_point_events
    GROUP BY user_id
    UNION ALL
    -- Include points from reports for users not yet in eco_point_events
    SELECT
      reporter_id AS user_id,
      (SUM(CASE WHEN severity = 'critical' THEN 50 ELSE 30 END) +
       SUM(CASE WHEN status = 'RESOLVED' THEN 20 ELSE 0 END))::BIGINT AS points
    FROM public.reports
    WHERE reporter_id NOT IN (SELECT DISTINCT user_id FROM public.eco_point_events)
      AND status NOT IN ('REJECTED', 'DUPLICATE')
    GROUP BY reporter_id
  ),
  aggregated AS (
    SELECT
      c.user_id,
      COALESCE(p.display_name, 'Student') AS display_name,
      SUM(c.points)::BIGINT AS total_points
    FROM combined_points c
    LEFT JOIN public.profiles p ON p.id = c.user_id
    GROUP BY c.user_id, p.display_name
  )
  SELECT
    user_id,
    display_name,
    total_points,
    ROW_NUMBER() OVER (ORDER BY total_points DESC)::BIGINT AS rank
  FROM aggregated
  WHERE total_points > 0
  ORDER BY total_points DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_eco_leaderboard(INTEGER) TO authenticated;
