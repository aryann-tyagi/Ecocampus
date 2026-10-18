-- Migration: 20261017000000_staff_admin_management_system.sql
-- Description: Core schema, RBAC tables, functions, RLS policies, and RPCs for Staff/Admin Issue Management.

-- 1. Ensure ecocampus_user_role enum exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ecocampus_user_role') THEN
    CREATE TYPE public.ecocampus_user_role AS ENUM ('student', 'staff', 'admin');
  END IF;
END $$;

-- 2. Seed default university departments if not already present
INSERT INTO public.departments (name, slug, active)
VALUES
  ('Housekeeping & Waste Management', 'housekeeping-waste', true),
  ('Plumbing & Facilities', 'plumbing-facilities', true),
  ('Electrical Maintenance', 'electrical-maintenance', true),
  ('Estate & Civil Infrastructure', 'estate-civil', true),
  ('Horticulture & Landscape', 'horticulture-landscape', true),
  ('Sanitation & Hygiene', 'sanitation-hygiene', true),
  ('General Administration', 'general-admin', true)
ON CONFLICT (name) DO NOTHING;

-- 3. Add assigned_department_id column to public.reports
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS assigned_department_id uuid REFERENCES public.departments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS reports_assigned_department_idx
  ON public.reports (assigned_department_id) WHERE assigned_department_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS reports_status_severity_created_idx
  ON public.reports (status, severity, created_at DESC);

-- 4. User roles & RBAC table
CREATE TABLE IF NOT EXISTS public.user_roles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.ecocampus_user_role NOT NULL DEFAULT 'student'::public.ecocampus_user_role,
  department_id uuid REFERENCES public.departments(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- 5. Helper security functions (SECURITY DEFINER with strict search_path)
CREATE OR REPLACE FUNCTION public.get_user_role(target_user_id uuid DEFAULT auth.uid())
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT COALESCE(
    (SELECT role::text FROM public.user_roles WHERE user_id = target_user_id),
    'student'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_admin(target_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = target_user_id AND role = 'admin'::public.ecocampus_user_role
  );
$$;

CREATE OR REPLACE FUNCTION public.is_staff(target_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = target_user_id AND (role = 'staff'::public.ecocampus_user_role OR role = 'admin'::public.ecocampus_user_role)
  );
$$;

CREATE OR REPLACE FUNCTION public.get_staff_department(target_user_id uuid DEFAULT auth.uid())
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT department_id FROM public.user_roles WHERE user_id = target_user_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_role(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_staff(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_staff_department(uuid) TO authenticated, anon;

-- 6. User Roles RLS Policies
DROP POLICY IF EXISTS "Users can read own role" ON public.user_roles;
CREATE POLICY "Users can read own role"
  ON public.user_roles FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Admins can read all roles" ON public.user_roles;
CREATE POLICY "Admins can read all roles"
  ON public.user_roles FOR SELECT TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can manage roles" ON public.user_roles;
CREATE POLICY "Admins can manage roles"
  ON public.user_roles FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 7. Reports RLS: Extend SELECT for Staff and Admin
DROP POLICY IF EXISTS "Staff and admins can read assigned and campus reports" ON public.reports;
CREATE POLICY "Staff and admins can read assigned and campus reports"
  ON public.reports FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR (public.is_staff() AND assigned_department_id = public.get_staff_department())
  );

-- 8. Report Media RLS: Extend SELECT for Staff and Admin
DROP POLICY IF EXISTS "Staff and admins can read report media" ON public.report_media;
CREATE POLICY "Staff and admins can read report media"
  ON public.report_media FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.reports r
      WHERE r.id = report_media.report_id
        AND public.is_staff()
        AND r.assigned_department_id = public.get_staff_department()
    )
  );

-- 9. Report Status Events RLS: Extend SELECT for Staff and Admin
DROP POLICY IF EXISTS "Staff and admins can read status events" ON public.report_status_events;
CREATE POLICY "Staff and admins can read status events"
  ON public.report_status_events FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.reports r
      WHERE r.id = report_status_events.report_id
        AND public.is_staff()
        AND r.assigned_department_id = public.get_staff_department()
    )
  );

-- 10. Storage Objects RLS: Allow Staff and Admin to read report photos
DROP POLICY IF EXISTS "Staff and admins can view report photos" ON storage.objects;
CREATE POLICY "Staff and admins can view report photos"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'report-photos'
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1
        FROM public.report_media rm
        JOIN public.reports r ON r.id = rm.report_id
        WHERE rm.storage_path = storage.objects.name
          AND public.is_staff()
          AND r.assigned_department_id = public.get_staff_department()
      )
    )
  );

-- 11. Atomic Server-Side RPC: Transition Report Status with Auditing
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
  v_event_id uuid;
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

  -- Insert immutable audit trail event
  INSERT INTO public.report_status_events (
    report_id, from_status, to_status, actor_id, note, occurred_at
  ) VALUES (
    p_report_id, v_old_status, p_new_status, v_caller_id, btrim(p_note), now()
  ) RETURNING id INTO v_event_id;

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

GRANT EXECUTE ON FUNCTION public.transition_report_status(uuid, public.ecocampus_report_status, text, uuid) TO authenticated;

-- 12. Atomic Server-Side RPC: Assign Department (Admin Only)
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
  v_old_dept uuid;
  v_dept_name text;
  v_new_status public.ecocampus_report_status;
BEGIN
  IF NOT public.is_admin(v_caller_id) THEN
    RAISE EXCEPTION 'Access denied. Only administrators can assign departments.' USING ERRCODE = '42501';
  END IF;

  SELECT name INTO v_dept_name FROM public.departments WHERE id = p_department_id AND active;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active department not found.' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_report FROM public.reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Report not found.' USING ERRCODE = 'P0002';
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

  INSERT INTO public.report_status_events (
    report_id, from_status, to_status, actor_id, note, occurred_at
  ) VALUES (
    p_report_id, v_report.status, v_new_status, v_caller_id,
    'Assigned to department: ' || v_dept_name,
    now()
  );

  RETURN jsonb_build_object(
    'ok', true,
    'report_id', p_report_id,
    'assigned_department_id', p_department_id,
    'department_name', v_dept_name,
    'status', v_new_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_report_department(uuid, uuid) TO authenticated;

-- 13. Auto-assign default 'student' role to newly registered users in auth trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, companion_name)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'display_name', 'Student'),
    'EcoBuddy'
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_roles (user_id, role)
  VALUES (new.id, 'student'::public.ecocampus_user_role)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN new;
END;
$$;
