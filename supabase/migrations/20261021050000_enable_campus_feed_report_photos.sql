-- Migration: 20261021050000_enable_campus_feed_report_photos.sql
-- Description: Enable authenticated users to retrieve and display report photo thumbnails
--              for active campus issues in the Nearby Issues home feed, while maintaining
--              private bucket security, RLS boundaries, and reporter privacy.

-- 1. Report Media RLS: Allow authenticated users to view media for active reports
DROP POLICY IF EXISTS "Authenticated users can view media of active reports" ON public.report_media;
CREATE POLICY "Authenticated users can view media of active reports"
  ON public.report_media FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.reports r
      WHERE r.id = report_media.report_id
        AND r.deleted_at IS NULL
    )
  );

-- 2. Storage Objects RLS: Allow authenticated users to read photos of active reports in report-photos bucket
DROP POLICY IF EXISTS "Authenticated users can view report photos of active reports" ON storage.objects;
CREATE POLICY "Authenticated users can view report photos of active reports"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'report-photos'
    AND EXISTS (
      SELECT 1
      FROM public.report_media rm
      JOIN public.reports r ON r.id = rm.report_id
      WHERE rm.storage_path = storage.objects.name
        AND r.deleted_at IS NULL
    )
  );

-- 3. Update get_campus_issue_feed RPC to return primary photo storage_path
DROP FUNCTION IF EXISTS public.get_campus_issue_feed(integer);

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
  longitude double precision,
  storage_path text
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
    r.longitude,
    (
      SELECT rm.storage_path
      FROM public.report_media rm
      WHERE rm.report_id = r.id
      ORDER BY rm.position ASC, rm.created_at ASC
      LIMIT 1
    ) AS storage_path
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
