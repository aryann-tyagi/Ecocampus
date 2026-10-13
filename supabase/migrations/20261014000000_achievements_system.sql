-- EcoCampus Migration: Achievements & Daily Challenges System
-- Documents the live Supabase RPC functions and schemas for reproducible deployments.
-- Includes get_my_achievements and get_my_daily_challenges (Asia/Kolkata timezone).

-- ============================================================================
-- 1. get_my_achievements() RPC
-- Returns all student achievements with target, progress, unlock status, and order.
-- Output columns:
--   achievement_key text,
--   title text,
--   description text,
--   icon_key text,
--   target_count integer,
--   progress_count integer,
--   is_unlocked boolean,
--   unlocked_at timestamptz,
--   sort_order integer
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_my_achievements()
RETURNS TABLE (
  achievement_key text,
  title text,
  description text,
  icon_key text,
  target_count integer,
  progress_count integer,
  is_unlocked boolean,
  unlocked_at timestamptz,
  sort_order integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_reported_count integer := 0;
  v_resolved_count integer := 0;
  v_first_report_at timestamptz;
  v_ten_reports_at timestamptz;
  v_ten_resolved_at timestamptz;
BEGIN
  IF v_user_id IS NOT NULL THEN
    -- Total non-rejected reports count
    SELECT COUNT(*)::integer INTO v_reported_count
    FROM public.reports
    WHERE reporter_id = v_user_id
      AND status NOT IN ('REJECTED', 'DUPLICATE');

    -- Total resolved reports count
    SELECT COUNT(*)::integer INTO v_resolved_count
    FROM public.reports
    WHERE reporter_id = v_user_id
      AND status = 'RESOLVED';

    -- Earliest report created_at for first_report unlocked_at
    SELECT MIN(created_at) INTO v_first_report_at
    FROM public.reports
    WHERE reporter_id = v_user_id
      AND status NOT IN ('REJECTED', 'DUPLICATE');

    -- 10th report created_at
    IF v_reported_count >= 10 THEN
      SELECT created_at INTO v_ten_reports_at
      FROM public.reports
      WHERE reporter_id = v_user_id
        AND status NOT IN ('REJECTED', 'DUPLICATE')
      ORDER BY created_at ASC
      OFFSET 9 LIMIT 1;
    END IF;

    -- 10th resolved report updated_at
    IF v_resolved_count >= 10 THEN
      SELECT updated_at INTO v_ten_resolved_at
      FROM public.reports
      WHERE reporter_id = v_user_id
        AND status = 'RESOLVED'
      ORDER BY updated_at ASC
      OFFSET 9 LIMIT 1;
    END IF;
  END IF;

  -- 1. First Report
  RETURN QUERY SELECT
    'first_report'::text AS achievement_key,
    'First Report'::text AS title,
    'Submit your first campus issue report.'::text AS description,
    'flag'::text AS icon_key,
    1::integer AS target_count,
    LEAST(v_reported_count, 1)::integer AS progress_count,
    (v_reported_count >= 1)::boolean AS is_unlocked,
    v_first_report_at AS unlocked_at,
    1::integer AS sort_order;

  -- 2. 10 Issues Reported
  RETURN QUERY SELECT
    'ten_reports'::text AS achievement_key,
    '10 Issues Reported'::text AS title,
    'Submit 10 campus issue reports.'::text AS description,
    'clipboard-check'::text AS icon_key,
    10::integer AS target_count,
    LEAST(v_reported_count, 10)::integer AS progress_count,
    (v_reported_count >= 10)::boolean AS is_unlocked,
    v_ten_reports_at AS unlocked_at,
    2::integer AS sort_order;

  -- 3. 10 Issues Resolved
  RETURN QUERY SELECT
    'ten_resolved'::text AS achievement_key,
    '10 Issues Resolved'::text AS title,
    'Have 10 of your reports reach Resolved status.'::text AS description,
    'check-circle'::text AS icon_key,
    10::integer AS target_count,
    LEAST(v_resolved_count, 10)::integer AS progress_count,
    (v_resolved_count >= 10)::boolean AS is_unlocked,
    v_ten_resolved_at AS unlocked_at,
    3::integer AS sort_order;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_achievements() TO authenticated;

-- ============================================================================
-- 2. get_my_daily_challenges() RPC
-- Returns student daily challenges computed for the current date in Asia/Kolkata.
-- Output columns:
--   challenge_key text,
--   title text,
--   description text,
--   target_count integer,
--   progress_count integer,
--   is_completed boolean,
--   challenge_date date,
--   sort_order integer
-- Rules:
--   - daily_reporter: >= 1 report of any category today.
--   - water_watch: >= 1 report with category = 'water' today.
--   - energy_check: >= 1 report with category = 'electricity' today.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_my_daily_challenges()
RETURNS TABLE (
  challenge_key text,
  title text,
  description text,
  target_count integer,
  progress_count integer,
  is_completed boolean,
  challenge_date date,
  sort_order integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_today date;
  v_daily_reports integer := 0;
  v_water_reports integer := 0;
  v_energy_reports integer := 0;
BEGIN
  -- Current date in Asia/Kolkata timezone
  v_today := (timezone('Asia/Kolkata', now()))::date;

  IF v_user_id IS NOT NULL THEN
    -- Any category report today
    SELECT COUNT(*)::integer INTO v_daily_reports
    FROM public.reports
    WHERE reporter_id = v_user_id
      AND status NOT IN ('REJECTED', 'DUPLICATE')
      AND (timezone('Asia/Kolkata', created_at))::date = v_today;

    -- Water category report today
    SELECT COUNT(*)::integer INTO v_water_reports
    FROM public.reports
    WHERE reporter_id = v_user_id
      AND category = 'water'
      AND status NOT IN ('REJECTED', 'DUPLICATE')
      AND (timezone('Asia/Kolkata', created_at))::date = v_today;

    -- Electricity category report today
    SELECT COUNT(*)::integer INTO v_energy_reports
    FROM public.reports
    WHERE reporter_id = v_user_id
      AND category = 'electricity'
      AND status NOT IN ('REJECTED', 'DUPLICATE')
      AND (timezone('Asia/Kolkata', created_at))::date = v_today;
  END IF;

  -- Challenge 1: Daily Reporter
  RETURN QUERY SELECT
    'daily_reporter'::text AS challenge_key,
    'Daily Reporter'::text AS title,
    'Submit one campus issue report today.'::text AS description,
    1::integer AS target_count,
    LEAST(v_daily_reports, 1)::integer AS progress_count,
    (v_daily_reports >= 1)::boolean AS is_completed,
    v_today AS challenge_date,
    1::integer AS sort_order;

  -- Challenge 2: Water Watch
  RETURN QUERY SELECT
    'water_watch'::text AS challenge_key,
    'Water Watch'::text AS title,
    'Submit one report in the Water category today.'::text AS description,
    1::integer AS target_count,
    LEAST(v_water_reports, 1)::integer AS progress_count,
    (v_water_reports >= 1)::boolean AS is_completed,
    v_today AS challenge_date,
    2::integer AS sort_order;

  -- Challenge 3: Energy Check
  RETURN QUERY SELECT
    'energy_check'::text AS challenge_key,
    'Energy Check'::text AS title,
    'Submit one report in the Electricity category today.'::text AS description,
    1::integer AS target_count,
    LEAST(v_energy_reports, 1)::integer AS progress_count,
    (v_energy_reports >= 1)::boolean AS is_completed,
    v_today AS challenge_date,
    3::integer AS sort_order;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_daily_challenges() TO authenticated;
