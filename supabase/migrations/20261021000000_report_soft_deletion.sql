-- Migration: 20261021000000_report_soft_deletion.sql
-- Description: Implement soft-deletion schema, administrative delete RPC, 
--              exclusion filters for public campus feeds, maps, and building summaries,
--              while keeping reports visible to their owning students with deletion reasons.

-- 1. Add soft-deletion metadata columns to public.reports
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS deleted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS deletion_reason text DEFAULT NULL;

-- 2. Performance indexes for soft deletion filtering and admin queries
CREATE INDEX IF NOT EXISTS idx_reports_deleted_at
  ON public.reports (deleted_at)
  WHERE deleted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_reports_active_created
  ON public.reports (created_at DESC)
  WHERE deleted_at IS NULL;

-- 3. Update get_campus_building_summary RPC to exclude soft-deleted reports
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
  LEFT JOIN public.reports AS r 
    ON r.building_id = b.id 
   AND r.deleted_at IS NULL
  WHERE b.active = true
    AND (SELECT auth.uid()) IS NOT NULL
  GROUP BY b.id, b.name
  ORDER BY b.name;
$function$;

REVOKE ALL ON FUNCTION public.get_campus_building_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_campus_building_summary() TO authenticated;

-- 4. Update get_campus_issue_feed RPC to exclude soft-deleted reports
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
  ORDER BY r.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
$function$;

REVOKE ALL ON FUNCTION public.get_campus_issue_feed(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_campus_issue_feed(integer) TO authenticated;

-- 5. Update find_duplicate_candidates RPC to exclude soft-deleted reports
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
    AND r.deleted_at IS NULL
    AND r.status IN ('REPORTED'::public.ecocampus_report_status, 'ASSIGNED'::public.ecocampus_report_status, 'IN_PROGRESS'::public.ecocampus_report_status)
    AND (
      p_category IS NULL
      OR r.category::text = p_category
      OR r.category::text = 'other'
      OR p_category = 'other'
    )
  ORDER BY
    (CASE WHEN p_floor_id IS NOT NULL AND r.floor_id = p_floor_id THEN 0 ELSE 1 END) ASC,
    r.created_at DESC
  LIMIT LEAST(p_limit, 25);
$$;

REVOKE ALL ON FUNCTION public.find_duplicate_candidates(uuid, text, uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_duplicate_candidates(uuid, text, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.find_duplicate_candidates(uuid, text, uuid, integer) TO anon;

-- 6. Atomic Server-Side RPC: Soft Delete Report (Admin Only)
CREATE OR REPLACE FUNCTION public.soft_delete_report(
  p_report_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_report record;
  v_trimmed_reason text;
  v_event_id uuid;
  v_now timestamptz := now();
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '28000';
  END IF;

  -- Verify administrative authority strictly on the server
  IF NOT public.is_admin(v_caller_id) THEN
    RAISE EXCEPTION 'Access denied. Only campus administrators can delete issue reports.' USING ERRCODE = '42501';
  END IF;

  -- Validate reason is provided and non-empty
  v_trimmed_reason := btrim(COALESCE(p_reason, ''));
  IF char_length(v_trimmed_reason) = 0 THEN
    RAISE EXCEPTION 'A deletion reason is required.' USING ERRCODE = '22000';
  END IF;

  -- Lock report row for atomic update
  SELECT * INTO v_report FROM public.reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Report not found with id %', p_report_id USING ERRCODE = 'P0002';
  END IF;

  -- Idempotency check: if already soft-deleted, return existing state gracefully
  IF v_report.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', true,
      'already_deleted', true,
      'report_id', p_report_id,
      'deleted_at', v_report.deleted_at,
      'deletion_reason', v_report.deletion_reason
    );
  END IF;

  -- Record soft deletion on the report
  UPDATE public.reports
  SET
    deleted_at = v_now,
    deleted_by = v_caller_id,
    deletion_reason = v_trimmed_reason,
    updated_at = v_now
  WHERE id = p_report_id;

  -- Insert immutable audit log entry into report_status_events preserving historical status
  INSERT INTO public.report_status_events (
    report_id,
    from_status,
    to_status,
    actor_id,
    note,
    occurred_at
  ) VALUES (
    p_report_id,
    v_report.status,
    v_report.status,
    v_caller_id,
    'Report removed by administrator. Reason: ' || v_trimmed_reason,
    v_now
  ) RETURNING id INTO v_event_id;

  -- Insert in-app notification for owning student (if reporter exists)
  IF v_report.reporter_id IS NOT NULL THEN
    INSERT INTO public.notifications (
      user_id,
      report_id,
      status_event_id,
      event_type,
      title,
      message,
      is_read,
      created_at
    ) VALUES (
      v_report.reporter_id,
      p_report_id,
      v_event_id,
      'report_deleted',
      'Report Removed by Administrator',
      'Your report "' || COALESCE(v_report.issue_label, 'Campus Issue') || '" was removed. Reason: ' || v_trimmed_reason,
      false,
      v_now
    )
    ON CONFLICT (user_id, status_event_id, event_type) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'report_id', p_report_id,
    'deleted_at', v_now,
    'deletion_reason', v_trimmed_reason,
    'event_id', v_event_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.soft_delete_report(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.soft_delete_report(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
