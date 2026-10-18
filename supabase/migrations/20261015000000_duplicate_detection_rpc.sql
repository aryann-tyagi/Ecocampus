-- EcoCampus Migration: Duplicate Report Candidate shortlisting RPC & Performance Indexes
-- Provides a bounded, privacy-preserving candidate search function for duplicate detection.
-- Strictly excludes private reporter identities, user IDs, private media paths, and internal notes.

-- 1. Performance Indexes for Candidate Lookup & Status Filtering
CREATE INDEX IF NOT EXISTS idx_reports_building_status
  ON public.reports (building_id, status)
  WHERE status IN ('REPORTED'::public.ecocampus_report_status, 'ASSIGNED'::public.ecocampus_report_status, 'IN_PROGRESS'::public.ecocampus_report_status);

CREATE INDEX IF NOT EXISTS idx_reports_category_status
  ON public.reports (category, status)
  WHERE status IN ('REPORTED'::public.ecocampus_report_status, 'ASSIGNED'::public.ecocampus_report_status, 'IN_PROGRESS'::public.ecocampus_report_status);

-- 2. Bounded Candidate Search RPC
-- Shortlists active, unresolved reports from the same building and compatible category
-- for multi-signal duplicate comparison.
CREATE OR REPLACE FUNCTION public.find_duplicate_candidates(
  p_building_id uuid,
  p_category text DEFAULT NULL,
  p_floor_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 10
)
RETURNS TABLE (
  id uuid,
  issue_label text,
  description text,
  category text,
  severity text,
  status text,
  building_id uuid,
  building_name text,
  floor_id uuid,
  floor_label text,
  location_details text,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT
    r.id,
    COALESCE(r.issue_label, 'Campus Issue') AS issue_label,
    COALESCE(r.description, '') AS description,
    r.category::text,
    r.severity::text,
    r.status::text,
    r.building_id,
    COALESCE(b.name, 'Campus Building') AS building_name,
    r.floor_id,
    COALESCE(f.label, r.floor_text) AS floor_label,
    COALESCE(r.location_details, '') AS location_details,
    r.created_at
  FROM public.reports r
  LEFT JOIN public.buildings b ON r.building_id = b.id
  LEFT JOIN public.floors f ON r.floor_id = f.id
  WHERE r.building_id = p_building_id
    AND r.status IN ('REPORTED'::public.ecocampus_report_status, 'ASSIGNED'::public.ecocampus_report_status, 'IN_PROGRESS'::public.ecocampus_report_status)
    AND (
      p_category IS NULL
      OR r.category::text = p_category
      OR r.category::text = 'other'
      OR p_category = 'other'
    )
  ORDER BY
    -- Prioritize same floor if provided
    (CASE WHEN p_floor_id IS NOT NULL AND r.floor_id = p_floor_id THEN 0 ELSE 1 END) ASC,
    r.created_at DESC
  LIMIT LEAST(p_limit, 25);
$$;

-- 3. Grant Permissions to authenticated and anon users
REVOKE ALL ON FUNCTION public.find_duplicate_candidates(uuid, text, uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_duplicate_candidates(uuid, text, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.find_duplicate_candidates(uuid, text, uuid, integer) TO anon;

NOTIFY pgrst, 'reload schema';
