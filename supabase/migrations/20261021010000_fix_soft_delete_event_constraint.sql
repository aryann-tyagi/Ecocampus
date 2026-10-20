-- Migration: 20261021010000_fix_soft_delete_event_constraint.sql
-- Description: Correct soft-delete RPC and status transition functions to respect the
--              report_status_events_check constraint ((from_status IS NULL) OR (from_status <> to_status)).
--              Soft-deletion records administrative removal on public.reports and sends a student notification
--              without attempting to insert an invalid non-transition into report_status_events.

-- 1. Correct soft_delete_report RPC
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
  v_now timestamptz := now();
BEGIN
  -- Strict authentication check
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

  -- Record soft deletion on the report using existing schema fields
  -- Preserves original status, category, severity, reporter_id, and history intact
  UPDATE public.reports
  SET
    deleted_at = v_now,
    deleted_by = v_caller_id,
    deletion_reason = v_trimmed_reason,
    updated_at = v_now
  WHERE id = p_report_id;

  -- Send student in-app notification without inserting an invalid row into report_status_events
  -- (status_event_id is nullable in public.notifications because deletion is not a status transition)
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
    )
    SELECT
      v_report.reporter_id,
      p_report_id,
      NULL,
      'report_deleted',
      'Report Removed by Administrator',
      'Your report "' || COALESCE(v_report.issue_label, 'Campus Issue') || '" was removed. Reason: ' || v_trimmed_reason,
      false,
      v_now
    WHERE NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.user_id = v_report.reporter_id
        AND n.report_id = p_report_id
        AND n.event_type = 'report_deleted'
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'report_id', p_report_id,
    'deleted_at', v_now,
    'deletion_reason', v_trimmed_reason
  );
END;
$$;

REVOKE ALL ON FUNCTION public.soft_delete_report(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.soft_delete_report(uuid, text) TO authenticated;

-- 2. Guard assign_report_department so re-assignment at same status does not violate report_status_events_check
CREATE OR REPLACE FUNCTION public.assign_report_department(
  p_report_id uuid,
  p_department_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_report record;
  v_dept_name text;
  v_old_dept uuid;
  v_new_status public.ecocampus_report_status;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '28000';
  END IF;

  IF NOT public.is_admin(v_caller_id) THEN
    RAISE EXCEPTION 'Access denied. Only administrators can assign issue departments.' USING ERRCODE = '42501';
  END IF;

  SELECT name INTO v_dept_name
  FROM public.departments
  WHERE id = p_department_id AND active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active department not found.' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_report FROM public.reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Report not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_report.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Cannot reassign a deleted report.' USING ERRCODE = '22000';
  END IF;

  v_old_dept := v_report.assigned_department_id;
  v_new_status := v_report.status;

  -- If still in REPORTED status, advance to ASSIGNED upon department assignment
  IF v_report.status = 'REPORTED' THEN
    v_new_status := 'ASSIGNED';
  END IF;

  UPDATE public.reports
  SET
    assigned_department_id = p_department_id,
    status = v_new_status,
    updated_at = now()
  WHERE id = p_report_id;

  -- Only record in report_status_events if status actually transitioned (satisfies report_status_events_check)
  IF v_report.status <> v_new_status THEN
    INSERT INTO public.report_status_events (
      report_id, from_status, to_status, actor_id, note, occurred_at
    ) VALUES (
      p_report_id, v_report.status, v_new_status, v_caller_id,
      'Assigned to department: ' || v_dept_name,
      now()
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'report_id', p_report_id,
    'assigned_department_id', p_department_id,
    'department_name', v_dept_name,
    'status', v_new_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.assign_report_department(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_report_department(uuid, uuid) TO authenticated;

-- 3. Guard transition_report_status so same-status reassignment does not violate report_status_events_check
CREATE OR REPLACE FUNCTION public.transition_report_status(
  p_report_id uuid,
  p_new_status public.ecocampus_report_status,
  p_note text DEFAULT NULL,
  p_assigned_department_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_is_admin boolean;
  v_is_staff boolean;
  v_staff_dept uuid;
  v_report record;
  v_old_status public.ecocampus_report_status;
  v_target_dept uuid;
  v_event_id uuid := NULL;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '28000';
  END IF;

  v_is_admin := public.is_admin(v_caller_id);
  v_is_staff := public.is_staff(v_caller_id);
  v_staff_dept := public.get_staff_department(v_caller_id);

  IF NOT (v_is_admin OR v_is_staff) THEN
    RAISE EXCEPTION 'Access denied. Only authorized staff and administrators can manage issue reports.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_report FROM public.reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Report not found with id %', p_report_id USING ERRCODE = 'P0002';
  END IF;

  IF v_report.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Cannot transition status on a deleted report.' USING ERRCODE = '22000';
  END IF;

  v_old_status := v_report.status;
  v_target_dept := COALESCE(p_assigned_department_id, v_report.assigned_department_id, v_report.suggested_department_id);

  -- Department Staff Scope Check
  IF v_is_staff AND NOT v_is_admin THEN
    IF v_report.assigned_department_id IS DISTINCT FROM v_staff_dept THEN
      RAISE EXCEPTION 'Access denied. You can only manage issues assigned to your department.' USING ERRCODE = '42501';
    END IF;

    IF p_assigned_department_id IS NOT NULL AND p_assigned_department_id IS DISTINCT FROM v_report.assigned_department_id THEN
      RAISE EXCEPTION 'Access denied. Only administrators can reassign report departments.' USING ERRCODE = '42501';
    END IF;

    -- Allowed staff workflow transitions: ASSIGNED -> IN_PROGRESS -> RESOLVED
    IF NOT (
      (v_old_status = 'ASSIGNED' AND p_new_status = 'IN_PROGRESS') OR
      (v_old_status = 'IN_PROGRESS' AND p_new_status = 'RESOLVED')
    ) THEN
      RAISE EXCEPTION 'Invalid status transition for staff: % to %', v_old_status, p_new_status USING ERRCODE = '22000';
    END IF;
  END IF;

  -- Admin Transition Validation
  IF v_is_admin THEN
    IF v_old_status = p_new_status AND p_assigned_department_id IS NULL THEN
      RAISE EXCEPTION 'Report is already in % status.', v_old_status USING ERRCODE = '22000';
    END IF;

    IF p_new_status = 'ASSIGNED' AND v_target_dept IS NULL THEN
      RAISE EXCEPTION 'Cannot transition to ASSIGNED without an assigned department.' USING ERRCODE = '22000';
    END IF;
  END IF;

  -- Resolution Note Requirement
  IF p_new_status = 'RESOLVED' AND (p_note IS NULL OR char_length(btrim(p_note)) = 0) THEN
    RAISE EXCEPTION 'A resolution note is required when resolving an issue.' USING ERRCODE = '22000';
  END IF;

  -- Update report row
  UPDATE public.reports
  SET
    status = p_new_status,
    assigned_department_id = v_target_dept,
    updated_at = now()
  WHERE id = p_report_id;

  -- Only record in report_status_events if status actually transitioned
  IF v_old_status <> p_new_status THEN
    INSERT INTO public.report_status_events (
      report_id, from_status, to_status, actor_id, note, occurred_at
    ) VALUES (
      p_report_id, v_old_status, p_new_status, v_caller_id, btrim(p_note), now()
    ) RETURNING id INTO v_event_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'report_id', p_report_id,
    'from_status', v_old_status,
    'to_status', p_new_status,
    'assigned_department_id', v_target_dept,
    'event_id', v_event_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.transition_report_status(uuid, public.ecocampus_report_status, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transition_report_status(uuid, public.ecocampus_report_status, text, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
