-- Migration: 20261022233000_authorized_staff_provisioning.sql
-- Description: Restrict EcoCampus Staff portal access to verified authorized staff email(s).
-- Enforces server-side allowlist, automatic department role provisioning,
-- trigger-level privilege escalation prevention, and strict department RLS scoping.

-- 1. Create Server-Side Staff Authorization Allowlist Table
CREATE TABLE IF NOT EXISTS public.authorized_staff_allowlist (
  email text PRIMARY KEY,
  department_slug text NOT NULL REFERENCES public.departments(slug) ON DELETE RESTRICT,
  active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS: Only campus administrators can view or edit the allowlist
ALTER TABLE public.authorized_staff_allowlist ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view staff allowlist" ON public.authorized_staff_allowlist;
CREATE POLICY "Admins can view staff allowlist"
  ON public.authorized_staff_allowlist FOR SELECT TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can manage staff allowlist" ON public.authorized_staff_allowlist;
CREATE POLICY "Admins can manage staff allowlist"
  ON public.authorized_staff_allowlist FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 2. Seed Authorized Staff Email for Housekeeping & Waste Management
INSERT INTO public.authorized_staff_allowlist (email, department_slug, active, notes)
VALUES (
  'staff@university.edu',
  'housekeeping-waste',
  true,
  'Dedicated authorized staff account for Housekeeping & Waste Management'
)
ON CONFLICT (email) DO UPDATE
  SET department_slug = EXCLUDED.department_slug,
      active = true,
      updated_at = now();

-- 3. Core Role Provisioning Function (SECURITY DEFINER with strict search_path)
CREATE OR REPLACE FUNCTION public.provision_user_role_from_allowlist(
  p_user_id uuid,
  p_email text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_dept_slug text;
  v_dept_id uuid;
  v_existing_role public.ecocampus_user_role;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  -- Check existing role if any
  SELECT role INTO v_existing_role FROM public.user_roles WHERE user_id = p_user_id;

  -- Do not demote an administrator
  IF v_existing_role = 'admin'::public.ecocampus_user_role THEN
    RETURN;
  END IF;

  -- Check if user's email matches active allowlist (case-insensitive)
  IF p_email IS NOT NULL AND char_length(btrim(p_email)) > 0 THEN
    SELECT department_slug INTO v_dept_slug
    FROM public.authorized_staff_allowlist
    WHERE lower(email) = lower(btrim(p_email)) AND active = true;

    IF v_dept_slug IS NOT NULL THEN
      SELECT id INTO v_dept_id FROM public.departments WHERE slug = v_dept_slug AND active;

      IF v_dept_id IS NOT NULL THEN
        -- Associate user UUID with the staff role and target department
        INSERT INTO public.user_roles (user_id, role, department_id, updated_at)
        VALUES (p_user_id, 'staff'::public.ecocampus_user_role, v_dept_id, now())
        ON CONFLICT (user_id) DO UPDATE
          SET role = 'staff'::public.ecocampus_user_role,
              department_id = v_dept_id,
              updated_at = now();
        RETURN;
      END IF;
    END IF;
  END IF;

  -- For all other users, default to student role
  INSERT INTO public.user_roles (user_id, role, department_id, updated_at)
  VALUES (p_user_id, 'student'::public.ecocampus_user_role, NULL, now())
  ON CONFLICT (user_id) DO UPDATE
    SET role = CASE
          WHEN public.user_roles.role = 'admin'::public.ecocampus_user_role THEN 'admin'::public.ecocampus_user_role
          ELSE 'student'::public.ecocampus_user_role
        END,
        department_id = CASE
          WHEN public.user_roles.role = 'admin'::public.ecocampus_user_role THEN public.user_roles.department_id
          ELSE NULL
        END,
        updated_at = now();
END;
$$;

-- 4. Enforce Trigger on public.user_roles to prevent unauthorized staff escalation
CREATE OR REPLACE FUNCTION public.validate_user_role_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_email text;
  v_dept_slug text;
  v_expected_dept_id uuid;
BEGIN
  -- If role is being assigned or updated to 'staff'
  IF NEW.role = 'staff'::public.ecocampus_user_role THEN
    -- Look up authentic email from auth.users
    SELECT email INTO v_user_email FROM auth.users WHERE id = NEW.user_id;

    IF v_user_email IS NULL THEN
      RAISE EXCEPTION 'Cannot assign staff role to non-existent auth user.' USING ERRCODE = '22000';
    END IF;

    -- Validate against trusted server-side allowlist
    SELECT department_slug INTO v_dept_slug
    FROM public.authorized_staff_allowlist
    WHERE lower(email) = lower(btrim(v_user_email)) AND active = true;

    IF v_dept_slug IS NULL THEN
      RAISE EXCEPTION 'Access denied. Email % is not authorized for EcoCampus staff access.', v_user_email USING ERRCODE = '42501';
    END IF;

    -- Ensure department_id matches the authorized department for this staff member
    SELECT id INTO v_expected_dept_id FROM public.departments WHERE slug = v_dept_slug AND active;
    IF NEW.department_id IS DISTINCT FROM v_expected_dept_id THEN
      NEW.department_id := v_expected_dept_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_user_role ON public.user_roles;
CREATE TRIGGER trg_validate_user_role
  BEFORE INSERT OR UPDATE ON public.user_roles
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_user_role_assignment();

-- 5. Update auth.users Trigger to integrate staff allowlist provisioning
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_is_test boolean := false;
BEGIN
  -- Mark automated test accounts if matching convention
  IF NEW.email LIKE 'test_%@example.com'
     OR NEW.email LIKE 'student_test_%@university.edu'
     OR NEW.email LIKE '%@campus.test' THEN
    v_is_test := true;
  END IF;

  -- Create default profile
  INSERT INTO public.profiles (id, display_name, companion_name, is_test)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'Student'),
    'EcoBuddy',
    v_is_test
  )
  ON CONFLICT (id) DO UPDATE
    SET is_test = EXCLUDED.is_test
    WHERE public.profiles.is_test IS DISTINCT FROM EXCLUDED.is_test;

  -- Provision role based on trusted allowlist (staff if authorized, otherwise student)
  PERFORM public.provision_user_role_from_allowlist(NEW.id, NEW.email);

  RETURN NEW;
END;
$$;

-- 6. Retroactively Provision any existing staff account and demote rogue staff
DO $$
DECLARE
  v_target_email text := 'staff@university.edu';
  v_staff_uid uuid;
BEGIN
  -- Provision staff@university.edu if it already exists in auth.users
  SELECT id INTO v_staff_uid FROM auth.users WHERE lower(email) = lower(v_target_email);
  IF v_staff_uid IS NOT NULL THEN
    PERFORM public.provision_user_role_from_allowlist(v_staff_uid, v_target_email);
  END IF;

  -- Demote any non-allowlisted staff accounts to student
  UPDATE public.user_roles ur
  SET role = 'student'::public.ecocampus_user_role,
      department_id = NULL,
      updated_at = now()
  FROM auth.users u
  WHERE ur.user_id = u.id
    AND ur.role = 'staff'::public.ecocampus_user_role
    AND lower(u.email) NOT IN (
      SELECT lower(email) FROM public.authorized_staff_allowlist WHERE active = true
    );
END $$;

-- 7. Verification RPC for Portal Authorization Status
CREATE OR REPLACE FUNCTION public.get_current_user_access()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_role public.ecocampus_user_role;
  v_dept_id uuid;
  v_dept_name text;
  v_dept_slug text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object(
      'authenticated', false,
      'role', 'anon',
      'can_access_portal', false
    );
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;
  SELECT ur.role, ur.department_id, d.name, d.slug
  INTO v_role, v_dept_id, v_dept_name, v_dept_slug
  FROM public.user_roles ur
  LEFT JOIN public.departments d ON d.id = ur.department_id
  WHERE ur.user_id = v_uid;

  v_role := COALESCE(v_role, 'student'::public.ecocampus_user_role);

  RETURN jsonb_build_object(
    'authenticated', true,
    'user_id', v_uid,
    'email', v_email,
    'role', v_role,
    'is_admin', (v_role = 'admin'::public.ecocampus_user_role),
    'is_staff', (v_role = 'staff'::public.ecocampus_user_role),
    'can_access_portal', (v_role = 'admin'::public.ecocampus_user_role OR v_role = 'staff'::public.ecocampus_user_role),
    'department_id', v_dept_id,
    'department_name', v_dept_name,
    'department_slug', v_dept_slug
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_current_user_access() TO authenticated, anon;
