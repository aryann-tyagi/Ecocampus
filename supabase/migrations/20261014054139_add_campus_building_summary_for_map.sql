
CREATE OR REPLACE FUNCTION public.get_campus_building_summary()
RETURNS TABLE (
  building_id uuid,
  building_name text,
  total_reports bigint,
  active_reports bigint,
  resolved_reports bigint,
  waste_reports bigint,
  water_reports bigint,
  electricity_reports bigint,
  infrastructure_reports bigint,
  greenery_reports bigint,
  cleanliness_reports bigint,
  other_reports bigint,
  reports_with_coordinates bigint,
  last_report_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    b.id AS building_id,
    b.name AS building_name,
    count(r.id)::bigint AS total_reports,
    count(r.id) FILTER (
      WHERE r.status <> 'RESOLVED'::public.ecocampus_report_status
    )::bigint AS active_reports,
    count(r.id) FILTER (
      WHERE r.status = 'RESOLVED'::public.ecocampus_report_status
    )::bigint AS resolved_reports,
    count(r.id) FILTER (WHERE r.category = 'waste'::public.ecocampus_issue_category)::bigint AS waste_reports,
    count(r.id) FILTER (WHERE r.category = 'water'::public.ecocampus_issue_category)::bigint AS water_reports,
    count(r.id) FILTER (WHERE r.category = 'electricity'::public.ecocampus_issue_category)::bigint AS electricity_reports,
    count(r.id) FILTER (WHERE r.category = 'infrastructure'::public.ecocampus_issue_category)::bigint AS infrastructure_reports,
    count(r.id) FILTER (WHERE r.category = 'greenery'::public.ecocampus_issue_category)::bigint AS greenery_reports,
    count(r.id) FILTER (WHERE r.category = 'cleanliness'::public.ecocampus_issue_category)::bigint AS cleanliness_reports,
    count(r.id) FILTER (WHERE r.category = 'other'::public.ecocampus_issue_category)::bigint AS other_reports,
    count(r.id) FILTER (
      WHERE r.latitude IS NOT NULL AND r.longitude IS NOT NULL
    )::bigint AS reports_with_coordinates,
    max(r.created_at) AS last_report_at
  FROM public.buildings AS b
  LEFT JOIN public.reports AS r ON r.building_id = b.id
  WHERE b.active = true
    AND (SELECT auth.uid()) IS NOT NULL
  GROUP BY b.id, b.name
  ORDER BY b.name;
$function$;

REVOKE ALL ON FUNCTION public.get_campus_building_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_campus_building_summary() TO authenticated;

NOTIFY pgrst, 'reload schema';
