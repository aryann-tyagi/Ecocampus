-- EcoCampus Migration: Live RPCs & Gamification Scoring Triggers
-- Reproduces the live Supabase RPC functions and triggers for reproducible deployments.

-- 1. get_campus_issue_feed(p_limit)
-- Returns sanitized campus issue cards without exposing reporter identities or private media.
CREATE OR REPLACE FUNCTION public.get_campus_issue_feed(p_limit integer DEFAULT 10)
RETURNS TABLE (
  id uuid,
  category text,
  severity text,
  issue_label text,
  description text,
  status text,
  created_at timestamptz,
  building_name text,
  floor_label text,
  location_details text,
  latitude double precision,
  longitude double precision
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    r.id,
    r.category::text,
    r.severity::text,
    COALESCE(r.issue_label, 'Campus Issue') AS issue_label,
    COALESCE(r.description, '') AS description,
    r.status::text,
    r.created_at,
    COALESCE(b.name, 'Campus Building') AS building_name,
    COALESCE(f.label, r.floor_text) AS floor_label,
    COALESCE(r.location_details, '') AS location_details,
    r.latitude,
    r.longitude
  FROM public.reports r
  LEFT JOIN public.buildings b ON r.building_id = b.id
  LEFT JOIN public.floors f ON r.floor_id = f.id
  WHERE r.status NOT IN ('REJECTED', 'DUPLICATE')
  ORDER BY r.created_at DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_campus_issue_feed(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_campus_issue_feed(integer) TO anon;

-- 2. Helper to determine level title and threshold
CREATE OR REPLACE FUNCTION public.calculate_eco_level(points integer)
RETURNS TABLE (
  level integer,
  level_title text,
  next_level_points integer,
  progress_percent numeric
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF points < 50 THEN
    RETURN QUERY SELECT 1, 'Seedling'::text, 50, ROUND((points::numeric / 50.0) * 100, 1);
  ELSIF points < 100 THEN
    RETURN QUERY SELECT 2, 'Sprout'::text, 100, ROUND(((points - 50)::numeric / 50.0) * 100, 1);
  ELSIF points < 200 THEN
    RETURN QUERY SELECT 3, 'Sapling'::text, 200, ROUND(((points - 100)::numeric / 100.0) * 100, 1);
  ELSIF points < 350 THEN
    RETURN QUERY SELECT 4, 'Tree'::text, 350, ROUND(((points - 200)::numeric / 150.0) * 100, 1);
  ELSE
    RETURN QUERY SELECT 5, 'Forest Guardian'::text, 350, 100.0::numeric;
  END IF;
END;
$$;

-- 3. get_my_eco_stats()
-- Returns total_points, eco_score, level, level_title, next_level_points, and progress_percent for auth.uid()
CREATE OR REPLACE FUNCTION public.get_my_eco_stats()
RETURNS TABLE (
  total_points integer,
  eco_score integer,
  level integer,
  level_title text,
  next_level_points integer,
  progress_percent numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_points integer := 0;
  v_score integer := 0;
  v_lvl record;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 0, 0, 1, 'Seedling'::text, 50, 0.0::numeric;
    RETURN;
  END IF;

  SELECT COALESCE(SUM(points), 0)::integer
  INTO v_points
  FROM public.eco_point_events
  WHERE user_id = v_user_id;

  v_score := LEAST(v_points, 100);

  SELECT * INTO v_lvl FROM public.calculate_eco_level(v_points);

  RETURN QUERY SELECT
    v_points,
    v_score,
    v_lvl.level,
    v_lvl.level_title,
    v_lvl.next_level_points,
    v_lvl.progress_percent;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_eco_stats() TO authenticated;

-- 4. get_campus_leaderboard(p_limit)
-- Returns rank, display_name, total_points, level, and level_title without exposing user IDs or emails.
CREATE OR REPLACE FUNCTION public.get_campus_leaderboard(p_limit integer DEFAULT 50)
RETURNS TABLE (
  rank integer,
  display_name text,
  total_points integer,
  level integer,
  level_title text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  WITH aggregated AS (
    SELECT
      p.id AS user_id,
      COALESCE(p.display_name, 'Student') AS display_name,
      COALESCE(SUM(e.points), 0)::integer AS total_points
    FROM public.profiles p
    LEFT JOIN public.eco_point_events e ON e.user_id = p.id
    GROUP BY p.id, p.display_name
  ),
  ranked AS (
    SELECT
      ROW_NUMBER() OVER (ORDER BY a.total_points DESC, a.display_name ASC)::integer AS rank,
      a.display_name,
      a.total_points,
      (SELECT lvl.level FROM public.calculate_eco_level(a.total_points) lvl) AS level,
      (SELECT lvl.level_title FROM public.calculate_eco_level(a.total_points) lvl) AS level_title
    FROM aggregated a
    WHERE a.total_points > 0
  )
  SELECT
    r.rank,
    r.display_name,
    r.total_points,
    r.level,
    r.level_title
  FROM ranked r
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_campus_leaderboard(integer) TO authenticated;

-- 5. Automatic Scoring Database Trigger
-- +5 points for submitted report, +15 points the first time a report reaches RESOLVED.
CREATE OR REPLACE FUNCTION public.handle_report_scoring()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Event 1: Report Submitted (+5 points)
  IF (TG_OP = 'INSERT') THEN
    IF NEW.reporter_id IS NOT NULL THEN
      INSERT INTO public.eco_point_events (
        user_id,
        action_type,
        points,
        idempotency_key,
        reference_id,
        description
      )
      VALUES (
        NEW.reporter_id,
        'report_submitted',
        5,
        'report_submitted:' || NEW.id::text,
        NEW.id,
        'Submitted report: ' || COALESCE(NEW.issue_label, 'Campus Issue')
      )
      ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;
    RETURN NEW;
  END IF;

  -- Event 2: Report Resolved (+15 points)
  IF (TG_OP = 'UPDATE') THEN
    IF (OLD.status != 'RESOLVED' AND NEW.status = 'RESOLVED') THEN
      IF NEW.reporter_id IS NOT NULL THEN
        INSERT INTO public.eco_point_events (
          user_id,
          action_type,
          points,
          idempotency_key,
          reference_id,
          description
        )
        VALUES (
          NEW.reporter_id,
          'report_resolved',
          15,
          'report_resolved:' || NEW.id::text,
          NEW.id,
          'Report resolved: ' || COALESCE(NEW.issue_label, 'Campus Issue')
        )
        ON CONFLICT (idempotency_key) DO NOTHING;
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_report_scoring ON public.reports;
CREATE TRIGGER trigger_report_scoring
  AFTER INSERT OR UPDATE OF status ON public.reports
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_report_scoring();
