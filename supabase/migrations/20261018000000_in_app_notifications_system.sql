-- Migration: 20261018000000_in_app_notifications_system.sql
-- Description: Implement complete in-app notification system with server-side triggers,
--              role-scoped notifications, idempotency unique constraints, and strict RLS.

-- 1. Create In-App Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  report_id uuid NOT NULL REFERENCES public.reports(id) ON DELETE CASCADE,
  status_event_id uuid REFERENCES public.report_status_events(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notifications_user_event_unique UNIQUE (user_id, status_event_id, event_type)
);

-- 2. Indexes for High-Performance Queries & Unread Badge Counts
CREATE INDEX IF NOT EXISTS notifications_user_unread_created_idx
  ON public.notifications (user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS notifications_report_idx
  ON public.notifications (report_id);

CREATE INDEX IF NOT EXISTS notifications_status_event_idx
  ON public.notifications (status_event_id);

-- 3. Row Level Security Mandate
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Clean existing policies if re-run
DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notification read status" ON public.notifications;

-- Access Policy: Users can only view their own notifications
CREATE POLICY "Users can read own notifications"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Access Policy: Users can only update their own notifications (e.g. is_read)
CREATE POLICY "Users can update own notification read status"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Revoke direct INSERT/DELETE from authenticated/anon: All creations happen strictly
-- through trusted server-side triggers to avoid fabricated notifications.
REVOKE INSERT, DELETE ON public.notifications FROM public, anon, authenticated;

-- 4. Server-Side Trigger: Generate Notifications from report_status_events
CREATE OR REPLACE FUNCTION public.process_report_status_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_report record;
  v_building_name text;
  v_dept_name text;
  v_admin_record record;
  v_staff_record record;
  v_student_title text;
  v_student_msg text;
  v_student_event_type text;
BEGIN
  -- Fetch report context
  SELECT r.*, b.name AS building_name
  INTO v_report
  FROM public.reports r
  LEFT JOIN public.buildings b ON b.id = r.building_id
  WHERE r.id = NEW.report_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  v_building_name := COALESCE(v_report.building_name, 'Campus');

  -- Fetch assigned department name if any
  IF v_report.assigned_department_id IS NOT NULL THEN
    SELECT name INTO v_dept_name
    FROM public.departments
    WHERE id = v_report.assigned_department_id;
  END IF;
  v_dept_name := COALESCE(v_dept_name, v_report.suggested_department_label, 'Facilities Management');

  -- =========================================================================
  -- A. STUDENT NOTIFICATIONS (Sent to report owner)
  -- =========================================================================
  IF v_report.reporter_id IS NOT NULL THEN
    IF NEW.from_status IS NULL AND NEW.to_status = 'REPORTED' THEN
      v_student_title := 'Report Submitted';
      v_student_msg := format('Your report for "%s" has been received and logged for review.', v_report.issue_label);
      v_student_event_type := 'report_submitted';
    ELSIF NEW.to_status = 'ASSIGNED' THEN
      v_student_title := 'Report Assigned';
      v_student_msg := format('Your report for "%s" has been assigned to %s.', v_report.issue_label, v_dept_name);
      v_student_event_type := 'report_assigned';
    ELSIF NEW.to_status = 'IN_PROGRESS' THEN
      v_student_title := 'Work in Progress';
      v_student_msg := format('Campus staff have begun work on "%s".', v_report.issue_label);
      v_student_event_type := 'report_in_progress';
    ELSIF NEW.to_status = 'RESOLVED' THEN
      v_student_title := 'Issue Resolved';
      IF NEW.note IS NOT NULL AND char_length(btrim(NEW.note)) > 0 THEN
        v_student_msg := format('Your report "%s" has been resolved. Note: %s', v_report.issue_label, btrim(NEW.note));
      ELSE
        v_student_msg := format('Your report "%s" has been resolved. Thank you for making our campus better!', v_report.issue_label);
      END IF;
      v_student_event_type := 'report_resolved';
    ELSIF NEW.to_status = 'REJECTED' THEN
      v_student_title := 'Report Rejected';
      IF NEW.note IS NOT NULL AND char_length(btrim(NEW.note)) > 0 THEN
        v_student_msg := format('Your report "%s" was not approved: %s', v_report.issue_label, btrim(NEW.note));
      ELSE
        v_student_msg := format('Your report "%s" could not be processed.', v_report.issue_label);
      END IF;
      v_student_event_type := 'report_rejected';
    ELSIF NEW.to_status = 'DUPLICATE' THEN
      v_student_title := 'Duplicate Report';
      v_student_msg := format('Your report "%s" was identified as a duplicate and merged with an existing issue.', v_report.issue_label);
      v_student_event_type := 'report_duplicate';
    END IF;

    IF v_student_title IS NOT NULL THEN
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
        NEW.report_id,
        NEW.id,
        v_student_event_type,
        v_student_title,
        v_student_msg,
        false,
        NEW.occurred_at
      )
      ON CONFLICT (user_id, status_event_id, event_type) DO NOTHING;
    END IF;
  END IF;

  -- =========================================================================
  -- B. STAFF & ADMIN NOTIFICATIONS (Role-scoped)
  -- =========================================================================

  -- 1. New Report -> Notify Administrators
  IF NEW.from_status IS NULL AND NEW.to_status = 'REPORTED' THEN
    FOR v_admin_record IN
      SELECT user_id FROM public.user_roles WHERE role = 'admin'
    LOOP
      -- Avoid sending admin alert to the reporter if the admin submitted it
      IF v_admin_record.user_id IS DISTINCT FROM v_report.reporter_id THEN
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
          v_admin_record.user_id,
          NEW.report_id,
          NEW.id,
          'admin_new_report',
          'New Issue Reported',
          format('New %s report at %s: "%s"', v_report.category, v_building_name, v_report.issue_label),
          false,
          NEW.occurred_at
        )
        ON CONFLICT (user_id, status_event_id, event_type) DO NOTHING;
      END IF;
    END LOOP;
  END IF;

  -- 2. Issue Assigned -> Notify Assigned Department Staff
  IF NEW.to_status = 'ASSIGNED' AND v_report.assigned_department_id IS NOT NULL THEN
    FOR v_staff_record IN
      SELECT user_id FROM public.user_roles
      WHERE role = 'staff' AND department_id = v_report.assigned_department_id
    LOOP
      IF v_staff_record.user_id IS DISTINCT FROM NEW.actor_id THEN
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
          v_staff_record.user_id,
          NEW.report_id,
          NEW.id,
          'staff_issue_assigned',
          'Issue Assigned to Department',
          format('New issue assigned to %s at %s: "%s"', v_dept_name, v_building_name, v_report.issue_label),
          false,
          NEW.occurred_at
        )
        ON CONFLICT (user_id, status_event_id, event_type) DO NOTHING;
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS trigger_process_report_status_notification ON public.report_status_events;

-- Attach trigger to report_status_events
CREATE TRIGGER trigger_process_report_status_notification
  AFTER INSERT ON public.report_status_events
  FOR EACH ROW
  EXECUTE FUNCTION public.process_report_status_notification();

-- 5. Safe Client RPC: Mark Notification as Read
CREATE OR REPLACE FUNCTION public.mark_notification_as_read(
  p_notification_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '28000';
  END IF;

  UPDATE public.notifications
  SET
    is_read = true,
    read_at = now()
  WHERE id = p_notification_id
    AND user_id = v_caller_id;

  RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_notification_as_read(uuid) TO authenticated;

-- 6. Safe Client RPC: Mark All Notifications as Read
CREATE OR REPLACE FUNCTION public.mark_all_notifications_as_read()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_updated_count integer;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '28000';
  END IF;

  WITH updated AS (
    UPDATE public.notifications
    SET
      is_read = true,
      read_at = now()
    WHERE user_id = v_caller_id
      AND is_read = false
    RETURNING id
  )
  SELECT count(*) INTO v_updated_count FROM updated;

  RETURN v_updated_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_all_notifications_as_read() TO authenticated;

-- 7. Safe Client RPC: Get Unread Notification Count
CREATE OR REPLACE FUNCTION public.get_unread_notification_count()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_unread_count integer;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT count(*)::integer INTO v_unread_count
  FROM public.notifications
  WHERE user_id = v_caller_id
    AND is_read = false;

  RETURN COALESCE(v_unread_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_unread_notification_count() TO authenticated;
