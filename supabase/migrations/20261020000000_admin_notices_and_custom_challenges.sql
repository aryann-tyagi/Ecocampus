-- Migration: 20261020000000_admin_notices_and_custom_challenges.sql
-- Description: Core schema, tables, RLS policies, trigger-based completion engine,
--              and RPCs for Admin Notice Management and Customizable Challenge System.

-- =============================================================================
-- 1. CAMPUS NOTICES SCHEMA
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.campus_notices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 2 AND 160),
  message text NOT NULL CHECK (char_length(btrim(message)) > 0),
  summary text CHECK (summary IS NULL OR char_length(btrim(summary)) <= 300),
  notice_type text NOT NULL CHECK (
    notice_type IN (
      'issue_notice',
      'campus_announcement',
      'maintenance_update',
      'utility_notice',
      'safety_notice',
      'general_notice'
    )
  ),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'important', 'urgent')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  target_building_id uuid REFERENCES public.buildings(id) ON DELETE SET NULL,
  is_pinned boolean NOT NULL DEFAULT false,
  starts_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  created_by uuid NOT NULL REFERENCES auth.users(id),
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notice_dates_check CHECK (expires_at IS NULL OR expires_at > starts_at)
);

CREATE INDEX IF NOT EXISTS idx_campus_notices_feed
  ON public.campus_notices (status, starts_at DESC, is_pinned DESC);

CREATE INDEX IF NOT EXISTS idx_campus_notices_building
  ON public.campus_notices (target_building_id)
  WHERE target_building_id IS NOT NULL;

-- Enable RLS on campus_notices
ALTER TABLE public.campus_notices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins have full access to notices" ON public.campus_notices;
DROP POLICY IF EXISTS "Students can read active published notices" ON public.campus_notices;

-- Admin Policy: Full CRUD for campus administrators
CREATE POLICY "Admins have full access to notices"
  ON public.campus_notices
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Student Policy: Read-only access to published, currently valid notices
CREATE POLICY "Students can read active published notices"
  ON public.campus_notices
  FOR SELECT
  TO authenticated
  USING (
    status = 'published'
    AND starts_at <= now()
    AND (expires_at IS NULL OR expires_at > now())
  );

-- RPC: Get Active Campus Notices for Student Application
CREATE OR REPLACE FUNCTION public.get_active_campus_notices(
  p_building_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  title text,
  message text,
  summary text,
  notice_type text,
  priority text,
  is_pinned boolean,
  target_building_id uuid,
  target_building_name text,
  starts_at timestamptz,
  expires_at timestamptz,
  published_at timestamptz,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    n.id,
    n.title,
    n.message,
    n.summary,
    n.notice_type,
    n.priority,
    n.is_pinned,
    n.target_building_id,
    b.name AS target_building_name,
    n.starts_at,
    n.expires_at,
    n.published_at,
    n.created_at
  FROM public.campus_notices n
  LEFT JOIN public.buildings b ON b.id = n.target_building_id
  WHERE n.status = 'published'
    AND n.starts_at <= now()
    AND (n.expires_at IS NULL OR n.expires_at > now())
    AND (
      n.target_building_id IS NULL
      OR p_building_id IS NULL
      OR n.target_building_id = p_building_id
    )
  ORDER BY n.is_pinned DESC, n.starts_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_active_campus_notices(uuid) TO authenticated;

-- RPC: Publish Campus Notice with Notification Fan-out
CREATE OR REPLACE FUNCTION public.publish_campus_notice(
  p_notice_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_notice record;
  v_target_user record;
  v_notif_count int := 0;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can publish campus notices'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_notice
  FROM public.campus_notices
  WHERE id = p_notice_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Notice not found'
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.campus_notices
  SET status = 'published',
      published_at = COALESCE(published_at, now()),
      updated_at = now()
  WHERE id = p_notice_id;

  -- If notice is important or urgent, notify students in public.notifications
  IF v_notice.priority IN ('important', 'urgent') THEN
    FOR v_target_user IN
      SELECT id FROM auth.users
    LOOP
      BEGIN
        INSERT INTO public.notifications (
          user_id,
          report_id,
          event_type,
          title,
          message,
          created_at
        )
        VALUES (
          v_target_user.id,
          -- Fallback report_id pointer: we associate to most recent report or dummy for notice
          (SELECT id FROM public.reports ORDER BY created_at DESC LIMIT 1),
          'campus_notice_' || v_notice.priority,
          v_notice.title,
          COALESCE(v_notice.summary, substring(v_notice.message from 1 for 100)),
          now()
        );
        v_notif_count := v_notif_count + 1;
      EXCEPTION WHEN OTHERS THEN
        -- Continue without blocking notice publication
      END;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'notice_id', p_notice_id,
    'notifications_generated', v_notif_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.publish_campus_notice(uuid) TO authenticated;


-- =============================================================================
-- 2. CUSTOMIZABLE CHALLENGES SCHEMA
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_key text NOT NULL UNIQUE CHECK (char_length(btrim(challenge_key)) BETWEEN 2 AND 60),
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 2 AND 160),
  description text NOT NULL CHECK (char_length(btrim(description)) > 0),
  instructions text NOT NULL CHECK (char_length(btrim(instructions)) > 0),
  challenge_type text NOT NULL CHECK (
    challenge_type IN (
      'report_issue',
      'category_reporting',
      'building_reporting',
      'multiple_reports'
    )
  ),
  category public.ecocampus_issue_category,
  building_id uuid REFERENCES public.buildings(id) ON DELETE SET NULL,
  target_count integer NOT NULL DEFAULT 1 CHECK (target_count >= 1),
  reward_points integer NOT NULL DEFAULT 25 CHECK (reward_points > 0 AND reward_points <= 1000),
  recurrence_type text NOT NULL DEFAULT 'one_time' CHECK (
    recurrence_type IN ('one_time', 'daily', 'weekly')
  ),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  is_pinned boolean NOT NULL DEFAULT false,
  starts_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT challenge_dates_check CHECK (ends_at IS NULL OR ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS idx_challenges_active
  ON public.challenges (status, starts_at, ends_at, is_pinned DESC);

-- Table: User Challenge Completions and Progress Tracking
CREATE TABLE IF NOT EXISTS public.user_challenge_completions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  challenge_id uuid NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  period_key text NOT NULL,
  progress_count integer NOT NULL DEFAULT 0,
  target_count integer NOT NULL,
  is_completed boolean NOT NULL DEFAULT false,
  completed_at timestamptz,
  points_awarded integer NOT NULL DEFAULT 0,
  last_qualifying_report_id uuid REFERENCES public.reports(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_challenge_period_unique UNIQUE (user_id, challenge_id, period_key)
);

CREATE INDEX IF NOT EXISTS idx_user_challenge_completions_lookup
  ON public.user_challenge_completions (user_id, challenge_id, period_key);

-- =============================================================================
-- 3. EXTEND ECO_POINT_EVENTS FOR CHALLENGE REWARDS
-- =============================================================================

-- Make report_id nullable in eco_point_events so challenge rewards can be logged cleanly
ALTER TABLE public.eco_point_events ALTER COLUMN report_id DROP NOT NULL;

-- Add challenge_completion_id column if not exists
ALTER TABLE public.eco_point_events
  ADD COLUMN IF NOT EXISTS challenge_completion_id uuid REFERENCES public.user_challenge_completions(id) ON DELETE CASCADE;

-- Update event_type constraint to allow 'challenge_completed'
ALTER TABLE public.eco_point_events
  DROP CONSTRAINT IF EXISTS eco_point_events_event_type_check;

ALTER TABLE public.eco_point_events
  ADD CONSTRAINT eco_point_events_event_type_check
  CHECK (event_type IN ('report_submitted', 'report_resolved', 'challenge_completed'));

-- Add unique constraint ensuring exactly one reward event per challenge completion
ALTER TABLE public.eco_point_events
  DROP CONSTRAINT IF EXISTS eco_point_events_challenge_unique;

ALTER TABLE public.eco_point_events
  ADD CONSTRAINT eco_point_events_challenge_unique
  UNIQUE (challenge_completion_id, event_type);

-- Enable RLS on challenges and completions
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_challenge_completions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins have full access to challenges" ON public.challenges;
DROP POLICY IF EXISTS "Students can view active published challenges" ON public.challenges;
DROP POLICY IF EXISTS "Users can read own challenge completions" ON public.user_challenge_completions;

-- Admin Policy: Full CRUD on challenges
CREATE POLICY "Admins have full access to challenges"
  ON public.challenges
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Student Policy: Read-only access to published challenges
CREATE POLICY "Students can view active published challenges"
  ON public.challenges
  FOR SELECT
  TO authenticated
  USING (
    status = 'published'
    AND starts_at <= now()
    AND (ends_at IS NULL OR ends_at > now())
  );

-- Policy: Users can only read their own challenge progress
CREATE POLICY "Users can read own challenge completions"
  ON public.user_challenge_completions
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Revoke direct INSERT/UPDATE/DELETE on user_challenge_completions from client
REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_challenge_completions FROM PUBLIC, anon, authenticated;

-- =============================================================================
-- 4. BACKEND-AUTHORITATIVE CHALLENGE VERIFICATION & REWARD ENGINE
-- =============================================================================

CREATE OR REPLACE FUNCTION public.sync_challenges_on_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_challenge record;
  v_period_key text;
  v_qualifies boolean;
  v_completion_id uuid;
  v_new_progress int;
  v_target int;
  v_is_already_completed boolean;
BEGIN
  -- We only evaluate challenges for genuine report insertions
  IF NEW.reporter_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Iterate through all published challenges currently active
  FOR v_challenge IN
    SELECT *
    FROM public.challenges
    WHERE status = 'published'
      AND starts_at <= now()
      AND (ends_at IS NULL OR ends_at > now())
  LOOP
    -- 1. Verify if the report satisfies the challenge criteria
    v_qualifies := true;

    IF v_challenge.challenge_type = 'category_reporting' THEN
      IF v_challenge.category IS NOT NULL AND NEW.category <> v_challenge.category THEN
        v_qualifies := false;
      END IF;
    ELSIF v_challenge.challenge_type = 'building_reporting' THEN
      IF v_challenge.building_id IS NOT NULL AND NEW.building_id <> v_challenge.building_id THEN
        v_qualifies := false;
      END IF;
    END IF;

    -- If category or building is specified regardless of type, enforce it
    IF v_challenge.category IS NOT NULL AND NEW.category <> v_challenge.category THEN
      v_qualifies := false;
    END IF;

    IF v_challenge.building_id IS NOT NULL AND NEW.building_id <> v_challenge.building_id THEN
      v_qualifies := false;
    END IF;

    IF v_qualifies THEN
      -- 2. Determine period boundary key
      IF v_challenge.recurrence_type = 'daily' THEN
        v_period_key := (now() AT TIME ZONE 'Asia/Kolkata')::date::text;
      ELSIF v_challenge.recurrence_type = 'weekly' THEN
        v_period_key := to_char(now() AT TIME ZONE 'Asia/Kolkata', 'IYYY-"W"IW');
      ELSE
        v_period_key := 'one_time';
      END IF;

      -- Check current completion state for this period
      SELECT id, progress_count, target_count, is_completed
      INTO v_completion_id, v_new_progress, v_target, v_is_already_completed
      FROM public.user_challenge_completions
      WHERE user_id = NEW.reporter_id
        AND challenge_id = v_challenge.id
        AND period_key = v_period_key;

      IF NOT FOUND THEN
        -- First qualifying action in this period
        v_new_progress := 1;
        v_target := v_challenge.target_count;
        v_is_already_completed := (v_new_progress >= v_target);

        INSERT INTO public.user_challenge_completions (
          user_id,
          challenge_id,
          period_key,
          progress_count,
          target_count,
          is_completed,
          completed_at,
          points_awarded,
          last_qualifying_report_id
        )
        VALUES (
          NEW.reporter_id,
          v_challenge.id,
          v_period_key,
          v_new_progress,
          v_target,
          v_is_already_completed,
          CASE WHEN v_is_already_completed THEN now() ELSE NULL END,
          CASE WHEN v_is_already_completed THEN v_challenge.reward_points ELSE 0 END,
          NEW.id
        )
        RETURNING id INTO v_completion_id;

        -- Award points if target met on first action
        IF v_is_already_completed THEN
          INSERT INTO public.eco_point_events (
            user_id,
            challenge_completion_id,
            event_type,
            points
          )
          VALUES (
            NEW.reporter_id,
            v_completion_id,
            'challenge_completed',
            v_challenge.reward_points
          )
          ON CONFLICT (challenge_completion_id, event_type) DO NOTHING;

          -- Add notification
          INSERT INTO public.notifications (
            user_id,
            report_id,
            event_type,
            title,
            message
          )
          VALUES (
            NEW.reporter_id,
            NEW.id,
            'challenge_completed',
            'Challenge Completed! 🎉',
            format('You earned +%s EcoPoints for completing "%s"!', v_challenge.reward_points, v_challenge.title)
          );
        END IF;

      ELSIF NOT v_is_already_completed THEN
        -- Advance progress towards target
        v_new_progress := v_new_progress + 1;
        v_is_already_completed := (v_new_progress >= v_target);

        UPDATE public.user_challenge_completions
        SET progress_count = v_new_progress,
            is_completed = v_is_already_completed,
            completed_at = CASE WHEN v_is_already_completed THEN now() ELSE completed_at END,
            points_awarded = CASE WHEN v_is_already_completed THEN v_challenge.reward_points ELSE 0 END,
            last_qualifying_report_id = NEW.id,
            updated_at = now()
        WHERE id = v_completion_id;

        -- Award points exactly once when completed
        IF v_is_already_completed THEN
          INSERT INTO public.eco_point_events (
            user_id,
            challenge_completion_id,
            event_type,
            points
          )
          VALUES (
            NEW.reporter_id,
            v_completion_id,
            'challenge_completed',
            v_challenge.reward_points
          )
          ON CONFLICT (challenge_completion_id, event_type) DO NOTHING;

          -- Add notification
          INSERT INTO public.notifications (
            user_id,
            report_id,
            event_type,
            title,
            message
          )
          VALUES (
            NEW.reporter_id,
            NEW.id,
            'challenge_completed',
            'Challenge Completed! 🎉',
            format('You earned +%s EcoPoints for completing "%s"!', v_challenge.reward_points, v_challenge.title)
          );
        END IF;
      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_challenges_after_report_insert ON public.reports;
CREATE TRIGGER sync_challenges_after_report_insert
AFTER INSERT ON public.reports
FOR EACH ROW
EXECUTE FUNCTION public.sync_challenges_on_report();

-- =============================================================================
-- 5. RPC: GET STUDENT CHALLENGES WITH LIVE PROGRESS
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_student_challenges()
RETURNS TABLE (
  id uuid,
  challenge_key text,
  title text,
  description text,
  instructions text,
  challenge_type text,
  category text,
  building_id uuid,
  building_name text,
  target_count integer,
  progress_count integer,
  is_completed boolean,
  reward_points integer,
  recurrence_type text,
  is_pinned boolean,
  starts_at timestamptz,
  ends_at timestamptz,
  period_key text,
  completed_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH current_periods AS (
    SELECT
      'one_time' AS one_time_key,
      (now() AT TIME ZONE 'Asia/Kolkata')::date::text AS daily_key,
      to_char(now() AT TIME ZONE 'Asia/Kolkata', 'IYYY-"W"IW') AS weekly_key
  )
  SELECT
    c.id,
    c.challenge_key,
    c.title,
    c.description,
    c.instructions,
    c.challenge_type,
    c.category::text,
    c.building_id,
    b.name AS building_name,
    c.target_count,
    COALESCE(ucc.progress_count, 0)::integer AS progress_count,
    COALESCE(ucc.is_completed, false) AS is_completed,
    c.reward_points,
    c.recurrence_type,
    c.is_pinned,
    c.starts_at,
    c.ends_at,
    CASE c.recurrence_type
      WHEN 'daily' THEN cp.daily_key
      WHEN 'weekly' THEN cp.weekly_key
      ELSE cp.one_time_key
    END AS period_key,
    ucc.completed_at
  FROM public.challenges c
  CROSS JOIN current_periods cp
  LEFT JOIN public.buildings b ON b.id = c.building_id
  LEFT JOIN public.user_challenge_completions ucc
    ON ucc.challenge_id = c.id
   AND ucc.user_id = auth.uid()
   AND ucc.period_key = CASE c.recurrence_type
                          WHEN 'daily' THEN cp.daily_key
                          WHEN 'weekly' THEN cp.weekly_key
                          ELSE cp.one_time_key
                        END
  WHERE c.status = 'published'
    AND c.starts_at <= now()
    AND (c.ends_at IS NULL OR c.ends_at > now())
  ORDER BY c.is_pinned DESC, c.starts_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_challenges() TO authenticated;

-- =============================================================================
-- 6. SEED INITIAL CUSTOMIZABLE CHALLENGES
-- =============================================================================

INSERT INTO public.challenges (
  challenge_key,
  title,
  description,
  instructions,
  challenge_type,
  category,
  target_count,
  reward_points,
  recurrence_type,
  status,
  is_pinned
)
VALUES
  (
    'daily_campus_reporter',
    'Daily Campus Reporter',
    'Keep SRM Sonepat clean and sustainable by reporting any active campus hazard.',
    'Take a photo of any waste, water leak, or electricity issue on campus and submit a verified report.',
    'report_issue',
    NULL,
    1,
    25,
    'daily',
    'published',
    true
  ),
  (
    'water_conservation_sentinel',
    'Water Conservation Sentinel',
    'Report water leaks, dripping taps, or overflow in washrooms and hostel blocks.',
    'Spot any water wastage on campus and log it under the Water category to preserve resources.',
    'category_reporting',
    'water',
    1,
    30,
    'daily',
    'published',
    false
  ),
  (
    'energy_efficiency_scout',
    'Energy Efficiency Scout',
    'Identify broken fixtures, burning lights in empty halls, or active ACs.',
    'Help cut campus power waste by logging electricity issues in classrooms or corridors.',
    'category_reporting',
    'electricity',
    1,
    30,
    'daily',
    'published',
    false
  ),
  (
    'waste_management_champion',
    'Campus Cleanup Champion',
    'Help maintain a pristine SRM Sonepat environment by reporting unmanaged litter.',
    'Submit 2 reports in the Waste or Cleanliness categories to earn bonus EcoPoints.',
    'multiple_reports',
    'waste',
    2,
    50,
    'weekly',
    'published',
    false
  )
ON CONFLICT (challenge_key) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  instructions = EXCLUDED.instructions,
  reward_points = EXCLUDED.reward_points,
  target_count = EXCLUDED.target_count,
  recurrence_type = EXCLUDED.recurrence_type,
  status = EXCLUDED.status;

-- Seed an initial sample published notice
INSERT INTO public.campus_notices (
  title,
  message,
  summary,
  notice_type,
  priority,
  status,
  is_pinned,
  created_by
)
SELECT
  'SRM Sonepat EcoCampus Initiative Active',
  'Welcome to the EcoCampus sustainability network. Report issues across academic blocks and hostels to help facilities resolve campus problems faster while earning EcoPoints.',
  'Welcome to EcoCampus. Report campus issues and track live resolutions.',
  'campus_announcement',
  'important',
  'published',
  true,
  (SELECT id FROM auth.users ORDER BY created_at LIMIT 1)
WHERE EXISTS (SELECT 1 FROM auth.users)
  AND NOT EXISTS (SELECT 1 FROM public.campus_notices WHERE title = 'SRM Sonepat EcoCampus Initiative Active');
