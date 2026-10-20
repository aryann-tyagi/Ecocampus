CREATE OR REPLACE FUNCTION public.audit_leaderboard_accounts()
RETURNS TABLE (
  user_id uuid,
  email text,
  display_name text,
  role text,
  metadata jsonb,
  total_points bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    u.id AS user_id,
    u.email::text AS email,
    p.display_name::text AS display_name,
    COALESCE(r.role::text, 'student') AS role,
    u.raw_user_meta_data AS metadata,
    COALESCE(SUM(e.points), 0)::bigint AS total_points
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  LEFT JOIN public.user_roles r ON r.user_id = u.id
  LEFT JOIN public.eco_point_events e ON e.user_id = u.id
  GROUP BY u.id, u.email, p.display_name, r.role, u.raw_user_meta_data
  HAVING COALESCE(SUM(e.points), 0) > 0;
$$;

CREATE OR REPLACE FUNCTION public.audit_user_events_and_reports()
RETURNS TABLE (
  user_id uuid,
  email text,
  display_name text,
  role text,
  report_id uuid,
  event_type text,
  points integer,
  event_created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    u.id AS user_id,
    u.email::text AS email,
    p.display_name::text AS display_name,
    COALESCE(r.role::text, 'student') AS role,
    e.report_id,
    e.event_type,
    e.points,
    e.created_at AS event_created_at
  FROM public.eco_point_events e
  JOIN auth.users u ON u.id = e.user_id
  LEFT JOIN public.profiles p ON p.id = u.id
  LEFT JOIN public.user_roles r ON r.user_id = u.id
  ORDER BY e.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.audit_leaderboard_accounts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_user_events_and_reports() TO authenticated;
