-- Migration: 20261021020000_hide_resolved_and_deleted_from_campus_feed.sql
-- Description: Exclude resolved and soft-deleted reports from get_campus_issue_feed RPC
--              at the data source level, ensuring the Home page Nearby Issues feed only displays
--              active campus issues (REPORTED, ASSIGNED, IN_PROGRESS) that have not been removed.

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
    AND r.deleted_at IS NULL
    AND r.status <> 'RESOLVED'::public.ecocampus_report_status
  ORDER BY r.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
$function$;

REVOKE ALL ON FUNCTION public.get_campus_issue_feed(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_campus_issue_feed(integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
