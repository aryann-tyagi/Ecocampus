
-- Minimal persistent achievements + real daily challenge progress.
-- Existing EcoPoints and leaderboard objects are deliberately untouched.

CREATE TABLE IF NOT EXISTS public.achievement_catalog (
  achievement_key text PRIMARY KEY,
  title text NOT NULL,
  description text NOT NULL,
  icon_key text NOT NULL,
  target_count integer NOT NULL CHECK (target_count > 0),
  sort_order integer NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true
);

INSERT INTO public.achievement_catalog
  (achievement_key, title, description, icon_key, target_count, sort_order, active)
VALUES
  ('first_report', 'First Report', 'Submit your first campus issue report.', 'flag', 1, 1, true),
  ('ten_reports', '10 Issues Reported', 'Submit 10 campus issue reports.', 'clipboard-check', 10, 2, true),
  ('ten_resolved', '10 Issues Resolved', 'Have 10 of your reports reach Resolved status.', 'check-circle', 10, 3, true)
ON CONFLICT (achievement_key) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  icon_key = EXCLUDED.icon_key,
  target_count = EXCLUDED.target_count,
  sort_order = EXCLUDED.sort_order,
  active = EXCLUDED.active;

CREATE TABLE IF NOT EXISTS public.user_achievements (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_key text NOT NULL REFERENCES public.achievement_catalog(achievement_key) ON DELETE RESTRICT,
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, achievement_key)
);

ALTER TABLE public.achievement_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.achievement_catalog FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.achievement_catalog TO authenticated;
DROP POLICY IF EXISTS "Authenticated users can read active achievement definitions" ON public.achievement_catalog;
CREATE POLICY "Authenticated users can read active achievement definitions"
ON public.achievement_catalog
FOR SELECT TO authenticated USING (active = true);

REVOKE ALL ON TABLE public.user_achievements FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.user_achievements TO authenticated;
DROP POLICY IF EXISTS "Users can read their own achievements" ON public.user_achievements;
CREATE POLICY "Users can read their own achievements"
ON public.user_achievements
FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);

CREATE INDEX IF NOT EXISTS reports_reporter_created_at_idx
ON public.reports (reporter_id, created_at);

CREATE INDEX IF NOT EXISTS reports_reporter_status_updated_idx
ON public.reports (reporter_id, status, updated_at);

CREATE OR REPLACE FUNCTION public.sync_report_achievements()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user uuid;
  v_report_count bigint;
  v_resolved_count bigint;
  v_first_report_at timestamptz;
  v_tenth_report_at timestamptz;
  v_tenth_resolved_at timestamptz;
BEGIN
  v_user := NEW.reporter_id;

  SELECT count(*), min(r.created_at)
    INTO v_report_count, v_first_report_at
  FROM public.reports r
  WHERE r.reporter_id = v_user;

  SELECT r.created_at INTO v_tenth_report_at
  FROM public.reports r
  WHERE r.reporter_id = v_user
  ORDER BY r.created_at, r.id
  OFFSET 9 LIMIT 1;

  SELECT count(*)
    INTO v_resolved_count
  FROM public.reports r
  WHERE r.reporter_id = v_user
    AND r.status = 'RESOLVED'::public.ecocampus_report_status;

  SELECT r.updated_at INTO v_tenth_resolved_at
  FROM public.reports r
  WHERE r.reporter_id = v_user
    AND r.status = 'RESOLVED'::public.ecocampus_report_status
  ORDER BY r.updated_at, r.id
  OFFSET 9 LIMIT 1;

  IF v_report_count >= 1 THEN
    INSERT INTO public.user_achievements (user_id, achievement_key, unlocked_at)
    VALUES (v_user, 'first_report', COALESCE(v_first_report_at, now()))
    ON CONFLICT (user_id, achievement_key) DO NOTHING;
  END IF;

  IF v_report_count >= 10 THEN
    INSERT INTO public.user_achievements (user_id, achievement_key, unlocked_at)
    VALUES (v_user, 'ten_reports', COALESCE(v_tenth_report_at, now()))
    ON CONFLICT (user_id, achievement_key) DO NOTHING;
  END IF;

  IF v_resolved_count >= 10 THEN
    INSERT INTO public.user_achievements (user_id, achievement_key, unlocked_at)
    VALUES (v_user, 'ten_resolved', COALESCE(v_tenth_resolved_at, now()))
    ON CONFLICT (user_id, achievement_key) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.sync_report_achievements() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS sync_report_achievements_after_insert ON public.reports;
CREATE TRIGGER sync_report_achievements_after_insert
AFTER INSERT ON public.reports
FOR EACH ROW EXECUTE FUNCTION public.sync_report_achievements();

DROP TRIGGER IF EXISTS sync_report_achievements_after_status_update ON public.reports;
CREATE TRIGGER sync_report_achievements_after_status_update
AFTER UPDATE OF status ON public.reports
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION public.sync_report_achievements();

-- Backfill from genuine historic reports; First Report unlocks for existing reporters.
INSERT INTO public.user_achievements (user_id, achievement_key, unlocked_at)
SELECT r.reporter_id, 'first_report', min(r.created_at)
FROM public.reports r
GROUP BY r.reporter_id
HAVING count(*) >= 1
ON CONFLICT (user_id, achievement_key) DO NOTHING;

INSERT INTO public.user_achievements (user_id, achievement_key, unlocked_at)
SELECT r.reporter_id, 'ten_reports', (array_agg(r.created_at ORDER BY r.created_at, r.id))[10]
FROM public.reports r
GROUP BY r.reporter_id
HAVING count(*) >= 10
ON CONFLICT (user_id, achievement_key) DO NOTHING;

INSERT INTO public.user_achievements (user_id, achievement_key, unlocked_at)
SELECT r.reporter_id, 'ten_resolved', (array_agg(r.updated_at ORDER BY r.updated_at, r.id))[10]
FROM public.reports r
WHERE r.status = 'RESOLVED'::public.ecocampus_report_status
GROUP BY r.reporter_id
HAVING count(*) >= 10
ON CONFLICT (user_id, achievement_key) DO NOTHING;

-- Minimal daily challenges, progress derived from the signed-in user's saved reports
-- created during the current Asia/Kolkata calendar day.
CREATE TABLE IF NOT EXISTS public.daily_challenge_catalog (
  challenge_key text PRIMARY KEY,
  title text NOT NULL,
  description text NOT NULL,
  category_keys text[] NULL,
  target_count integer NOT NULL CHECK (target_count > 0),
  sort_order integer NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true
);

INSERT INTO public.daily_challenge_catalog
  (challenge_key, title, description, category_keys, target_count, sort_order, active)
VALUES
  ('daily_reporter', 'Daily Reporter', 'Submit one campus issue report today.', NULL, 1, 1, true),
  ('water_watch', 'Water Watch', 'Submit one report in the Water category today.', ARRAY['water']::text[], 1, 2, true),
  ('energy_check', 'Energy Check', 'Submit one report in the Electricity category today.', ARRAY['electricity']::text[], 1, 3, true)
ON CONFLICT (challenge_key) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  category_keys = EXCLUDED.category_keys,
  target_count = EXCLUDED.target_count,
  sort_order = EXCLUDED.sort_order,
  active = EXCLUDED.active;

ALTER TABLE public.daily_challenge_catalog ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.daily_challenge_catalog FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.daily_challenge_catalog TO authenticated;
DROP POLICY IF EXISTS "Authenticated users can read active daily challenges" ON public.daily_challenge_catalog;
CREATE POLICY "Authenticated users can read active daily challenges"
ON public.daily_challenge_catalog
FOR SELECT TO authenticated USING (active = true);

CREATE OR REPLACE FUNCTION public.get_my_achievements()
RETURNS TABLE (
  achievement_key text,
  title text,
  description text,
  icon_key text,
  target_count integer,
  progress_count bigint,
  is_unlocked boolean,
  unlocked_at timestamptz,
  sort_order integer
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
  WITH current_user_reports AS (
    SELECT
      count(*)::bigint AS submitted_count,
      count(*) FILTER (
        WHERE r.status = 'RESOLVED'::public.ecocampus_report_status
      )::bigint AS resolved_count
    FROM public.reports r
    WHERE r.reporter_id = (SELECT auth.uid())
  )
  SELECT
    c.achievement_key,
    c.title,
    c.description,
    c.icon_key,
    c.target_count,
    CASE c.achievement_key
      WHEN 'first_report' THEN u.submitted_count
      WHEN 'ten_reports' THEN u.submitted_count
      WHEN 'ten_resolved' THEN u.resolved_count
      ELSE 0::bigint
    END AS progress_count,
    (ua.user_id IS NOT NULL) AS is_unlocked,
    ua.unlocked_at,
    c.sort_order
  FROM public.achievement_catalog c
  CROSS JOIN current_user_reports u
  LEFT JOIN public.user_achievements ua
    ON ua.achievement_key = c.achievement_key
   AND ua.user_id = (SELECT auth.uid())
  WHERE (SELECT auth.uid()) IS NOT NULL
    AND c.active = true
  ORDER BY c.sort_order, c.achievement_key;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_daily_challenges()
RETURNS TABLE (
  challenge_key text,
  title text,
  description text,
  target_count integer,
  progress_count bigint,
  is_completed boolean,
  challenge_date date,
  sort_order integer
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
  WITH local_day AS (
    SELECT (now() AT TIME ZONE 'Asia/Kolkata')::date AS today
  )
  SELECT
    c.challenge_key,
    c.title,
    c.description,
    c.target_count,
    p.progress_count,
    (p.progress_count >= c.target_count) AS is_completed,
    d.today AS challenge_date,
    c.sort_order
  FROM public.daily_challenge_catalog c
  CROSS JOIN local_day d
  CROSS JOIN LATERAL (
    SELECT count(*)::bigint AS progress_count
    FROM public.reports r
    WHERE r.reporter_id = (SELECT auth.uid())
      AND r.created_at >= (d.today::timestamp AT TIME ZONE 'Asia/Kolkata')
      AND r.created_at < ((d.today + 1)::timestamp AT TIME ZONE 'Asia/Kolkata')
      AND (
        c.category_keys IS NULL
        OR r.category::text = ANY (c.category_keys)
      )
  ) p
  WHERE (SELECT auth.uid()) IS NOT NULL
    AND c.active = true
  ORDER BY c.sort_order, c.challenge_key;
$function$;

REVOKE ALL ON FUNCTION public.get_my_achievements() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_achievements() TO authenticated;
REVOKE ALL ON FUNCTION public.get_my_daily_challenges() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_daily_challenges() TO authenticated;

NOTIFY pgrst, 'reload schema';
