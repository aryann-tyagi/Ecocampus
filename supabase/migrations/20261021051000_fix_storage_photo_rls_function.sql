-- Migration: 20261021051000_fix_storage_photo_rls_function.sql
-- Description: Use SECURITY DEFINER helper functions for storage.objects and report_media RLS checks
--              to prevent recursive RLS filtering when authenticated students access photos
--              for active campus reports in the Nearby Issues feed.

-- 1. Helper function for report_media RLS check
CREATE OR REPLACE FUNCTION public.can_view_report_media(target_report_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.reports r
    WHERE r.id = target_report_id
      AND r.deleted_at IS NULL
  );
$$;

REVOKE ALL ON FUNCTION public.can_view_report_media(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_view_report_media(uuid) TO authenticated;

-- 2. Helper function for storage.objects RLS check
CREATE OR REPLACE FUNCTION public.can_view_report_photo(storage_path text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.report_media rm
    JOIN public.reports r ON r.id = rm.report_id
    WHERE rm.storage_path = storage_path
      AND r.deleted_at IS NULL
  );
$$;

REVOKE ALL ON FUNCTION public.can_view_report_photo(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_view_report_photo(text) TO authenticated;

-- 3. Update report_media policy
DROP POLICY IF EXISTS "Authenticated users can view media of active reports" ON public.report_media;
CREATE POLICY "Authenticated users can view media of active reports"
  ON public.report_media FOR SELECT TO authenticated
  USING (
    public.can_view_report_media(report_id)
  );

-- 4. Update storage.objects policy
DROP POLICY IF EXISTS "Authenticated users can view report photos of active reports" ON storage.objects;
CREATE POLICY "Authenticated users can view report photos of active reports"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'report-photos'
    AND public.can_view_report_photo(storage.objects.name)
  );

NOTIFY pgrst, 'reload schema';
