
-- Campus feed, account-scoped EcoPoints, score/level stats, and leaderboard.
-- Public issue cards deliberately omit reporter IDs and media/storage paths.

CREATE TABLE IF NOT EXISTS public.eco_point_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  report_id uuid NOT NULL REFERENCES public.reports(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('report_submitted', 'report_resolved')),
  points integer NOT NULL CHECK (points > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT eco_point_events_report_event_unique UNIQUE (report_id, event_type)
);

ALTER TABLE public.eco_point_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.eco_point_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.eco_point_events TO authenticated;

DROP POLICY IF EXISTS "Users can read their own EcoPoints events" ON public.eco_point_events;
CREATE POLICY "Users can read their own EcoPoints events"
ON public.eco_point_events
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = user_id);

CREATE INDEX IF NOT EXISTS eco_point_events_user_created_idx
ON public.eco_point_events (user_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.award_report_eco_points()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- +5 points for a newly submitted report. The unique constraint makes
    -- retries idempotent for the same report.
    INSERT INTO public.eco_point_events (user_id, report_id, event_type, points)
    VALUES (NEW.reporter_id, NEW.id, 'report_submitted', 5)
    ON CONFLICT (report_id, event_type) DO NOTHING;

  ELSIF TG_OP = 'UPDATE'
    AND OLD.status IS DISTINCT FROM NEW.status
    AND NEW.status = 'RESOLVED'::public.ecocampus_report_status THEN
    -- +15 bonus points the first time a report reaches RESOLVED.
    INSERT INTO public.eco_point_events (user_id, report_id, event_type, points)
    VALUES (NEW.reporter_id, NEW.id, 'report_resolved', 15)
    ON CONFLICT (report_id, event_type) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.award_report_eco_points() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS award_report_eco_points_after_insert ON public.reports;
CREATE TRIGGER award_report_eco_points_after_insert
AFTER INSERT ON public.reports
FOR EACH ROW
EXECUTE FUNCTION public.award_report_eco_points();

DROP TRIGGER IF EXISTS award_report_eco_points_after_resolve ON public.reports;
CREATE TRIGGER award_report_eco_points_after_resolve
AFTER UPDATE OF status ON public.reports
FOR EACH ROW
EXECUTE FUNCTION public.award_report_eco_points();

-- Backfill only events for genuine existing report rows; no synthetic reports.
INSERT INTO public.eco_point_events (user_id, report_id, event_type, points, created_at)
SELECT r.reporter_id, r.id, 'report_submitted', 5, r.created_at
FROM public.reports AS r
ON CONFLICT (report_id, event_type) DO NOTHING;

INSERT INTO public.eco_point_events (user_id, report_id, event_type, points, created_at)
SELECT r.reporter_id, r.id, 'report_resolved', 15, r.updated_at
FROM public.reports AS r
WHERE r.status = 'RESOLVED'::public.ecocampus_report_status
ON CONFLICT (report_id, event_type) DO NOTHING;

CREATE OR REPLACE FUNCTION public.get_my_eco_stats()
RETURNS TABLE (
  total_points bigint,
  eco_score integer,
  level integer,
  level_title text,
  next_level_points bigint,
  progress_percent integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH points AS (
    SELECT COALESCE(SUM(e.points), 0)::bigint AS total
    FROM public.eco_point_events AS e
    WHERE e.user_id = (SELECT auth.uid())
  )
  SELECT
    p.total AS total_points,
    LEAST(p.total, 100)::integer AS eco_score,
    CASE
      WHEN p.total < 50 THEN 1
      WHEN p.total < 100 THEN 2
      WHEN p.total < 200 THEN 3
      WHEN p.total < 350 THEN 4
      ELSE 5
    END AS level,
    CASE
      WHEN p.total < 50 THEN 'Seedling'
      WHEN p.total < 100 THEN 'Sprout'
      WHEN p.total < 200 THEN 'Sapling'
      WHEN p.total < 350 THEN 'Tree'
      ELSE 'Forest Guardian'
    END AS level_title,
    CASE
      WHEN p.total < 50 THEN 50 - p.total
      WHEN p.total < 100 THEN 100 - p.total
      WHEN p.total < 200 THEN 200 - p.total
      WHEN p.total < 350 THEN 350 - p.total
      ELSE NULL
    END AS next_level_points,
    CASE
      WHEN p.total < 50 THEN ((p.total * 100) / 50)::integer
      WHEN p.total < 100 THEN (((p.total - 50) * 100) / 50)::integer
      WHEN p.total < 200 THEN (((p.total - 100) * 100) / 100)::integer
      WHEN p.total < 350 THEN (((p.total - 200) * 100) / 150)::integer
      ELSE NULL
    END AS progress_percent
  FROM points AS p
  WHERE (SELECT auth.uid()) IS NOT NULL;
$function$;

CREATE OR REPLACE FUNCTION public.get_campus_leaderboard(p_limit integer DEFAULT 50)
RETURNS TABLE (
  rank bigint,
  display_name text,
  total_points bigint,
  level integer,
  level_title text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH totals AS (
    SELECT e.user_id, SUM(e.points)::bigint AS points
    FROM public.eco_point_events AS e
    GROUP BY e.user_id
  ),
  ranked AS (
    SELECT
      ROW_NUMBER() OVER (ORDER BY t.points DESC, p.display_name ASC, p.id ASC)::bigint AS position,
      COALESCE(NULLIF(BTRIM(p.display_name), ''), 'Campus student') AS student_name,
      t.points,
      CASE
        WHEN t.points < 50 THEN 1
        WHEN t.points < 100 THEN 2
        WHEN t.points < 200 THEN 3
        WHEN t.points < 350 THEN 4
        ELSE 5
      END AS student_level,
      CASE
        WHEN t.points < 50 THEN 'Seedling'
        WHEN t.points < 100 THEN 'Sprout'
        WHEN t.points < 200 THEN 'Sapling'
        WHEN t.points < 350 THEN 'Tree'
        ELSE 'Forest Guardian'
      END AS student_level_title
    FROM totals AS t
    JOIN public.profiles AS p ON p.id = t.user_id
    WHERE t.points > 0
  )
  SELECT r.position, r.student_name, r.points, r.student_level, r.student_level_title
  FROM ranked AS r
  WHERE r.position <= LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100)
    AND (SELECT auth.uid()) IS NOT NULL
  ORDER BY r.position;
$function$;

CREATE OR REPLACE FUNCTION public.get_campus_issue_feed(p_limit integer DEFAULT 50)
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
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    r.id,
    r.category::text,
    r.severity::text,
    r.issue_label,
    r.description,
    r.status::text,
    r.created_at,
    b.name,
    f.label,
    r.location_details,
    r.latitude,
    r.longitude
  FROM public.reports AS r
  JOIN public.buildings AS b ON b.id = r.building_id
  LEFT JOIN public.floors AS f ON f.id = r.floor_id
  WHERE (SELECT auth.uid()) IS NOT NULL
  ORDER BY r.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
$function$;

REVOKE ALL ON FUNCTION public.get_my_eco_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_eco_stats() TO authenticated;

REVOKE ALL ON FUNCTION public.get_campus_leaderboard(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_campus_leaderboard(integer) TO authenticated;

REVOKE ALL ON FUNCTION public.get_campus_issue_feed(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_campus_issue_feed(integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
