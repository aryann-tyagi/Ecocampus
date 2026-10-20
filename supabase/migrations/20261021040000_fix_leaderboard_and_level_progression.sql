-- Migration: 20261021040000_fix_leaderboard_and_level_progression.sql
-- Description:
-- 1. Add is_test marker to public.profiles and mark verified test accounts.
-- 2. Update get_my_eco_stats RPC to return authoritative level thresholds and progress.
-- 3. Update get_campus_leaderboard RPC to safely exclude verified test accounts server-side.
-- 4. Update handle_new_user trigger to preserve is_test marker for test signups.
-- 5. Drop temporary audit functions.

-- 1. Add is_test column to profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_test boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS profiles_is_test_idx
  ON public.profiles (is_test) WHERE is_test = true;

-- 2. Flag verified test accounts in public.profiles and auth.users raw_app_meta_data
UPDATE public.profiles p
SET is_test = true
FROM auth.users u
WHERE p.id = u.id
  AND (
    u.email LIKE 'student_test_%@university.edu'
    OR u.email LIKE '%@campus.test'
    OR (u.email = 'random@gmail.com' AND p.display_name = 'System')
    OR (u.raw_user_meta_data->>'is_test')::boolean = true
    OR (u.raw_app_meta_data->>'is_test')::boolean = true
  );

UPDATE auth.users
SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || '{"is_test": true}'::jsonb
WHERE (
  email LIKE 'student_test_%@university.edu'
  OR email LIKE '%@campus.test'
  OR (email = 'random@gmail.com' AND (raw_user_meta_data->>'display_name' = 'System' OR raw_user_meta_data->>'name' = 'System'))
  OR (raw_user_meta_data->>'is_test')::boolean = true
);

-- 3. Update handle_new_user trigger to support is_test marker
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_is_test boolean := false;
BEGIN
  IF (NEW.raw_user_meta_data->>'is_test')::boolean = true
     OR (NEW.raw_app_meta_data->>'is_test')::boolean = true
     OR NEW.email LIKE 'student_test_%@university.edu'
     OR NEW.email LIKE '%@campus.test' THEN
    v_is_test := true;
  END IF;

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

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'student'::public.ecocampus_user_role)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- 4. Correct get_my_eco_stats RPC
CREATE OR REPLACE FUNCTION public.get_my_eco_stats()
RETURNS TABLE (
  total_points bigint,
  eco_score integer,
  level integer,
  level_title text,
  next_level_points bigint,
  progress_percent integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH points AS (
    SELECT COALESCE(SUM(e.points), 0)::bigint AS total
    FROM public.eco_point_events AS e
    WHERE e.user_id = (SELECT auth.uid())
  )
  SELECT
    p.total AS total_points,
    LEAST(p.total, 100)::integer AS eco_score,
    CASE
      WHEN p.total < 50 THEN 1
      WHEN p.total < 100 THEN 2
      WHEN p.total < 200 THEN 3
      WHEN p.total < 350 THEN 4
      ELSE 5
    END AS level,
    CASE
      WHEN p.total < 50 THEN 'Seedling'
      WHEN p.total < 100 THEN 'Sprout'
      WHEN p.total < 200 THEN 'Sapling'
      WHEN p.total < 350 THEN 'Tree'
      ELSE 'Forest Guardian'
    END AS level_title,
    CASE
      WHEN p.total < 50 THEN 50
      WHEN p.total < 100 THEN 100
      WHEN p.total < 200 THEN 200
      WHEN p.total < 350 THEN 350
      ELSE NULL
    END AS next_level_points,
    CASE
      WHEN p.total < 50 THEN ((p.total * 100) / 50)::integer
      WHEN p.total < 100 THEN (((p.total - 50) * 100) / 50)::integer
      WHEN p.total < 200 THEN (((p.total - 100) * 100) / 100)::integer
      WHEN p.total < 350 THEN (((p.total - 200) * 100) / 150)::integer
      ELSE 100
    END AS progress_percent
  FROM points AS p
  WHERE (SELECT auth.uid()) IS NOT NULL;
$function$;

REVOKE ALL ON FUNCTION public.get_my_eco_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_eco_stats() TO authenticated;

-- 5. Correct get_campus_leaderboard RPC
DROP FUNCTION IF EXISTS public.get_campus_leaderboard(integer);

CREATE OR REPLACE FUNCTION public.get_campus_leaderboard(p_limit integer DEFAULT 50)
RETURNS TABLE (
  rank bigint,
  display_name text,
  total_points bigint,
  level integer,
  level_title text,
  user_id uuid
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH totals AS (
    SELECT e.user_id, SUM(e.points)::bigint AS points
    FROM public.eco_point_events AS e
    GROUP BY e.user_id
  ),
  ranked AS (
    SELECT
      ROW_NUMBER() OVER (ORDER BY t.points DESC, p.display_name ASC, p.id ASC)::bigint AS position,
      COALESCE(NULLIF(BTRIM(p.display_name), ''), 'Campus student') AS student_name,
      t.points,
      CASE
        WHEN t.points < 50 THEN 1
        WHEN t.points < 100 THEN 2
        WHEN t.points < 200 THEN 3
        WHEN t.points < 350 THEN 4
        ELSE 5
      END AS student_level,
      CASE
        WHEN t.points < 50 THEN 'Seedling'
        WHEN t.points < 100 THEN 'Sprout'
        WHEN t.points < 200 THEN 'Sapling'
        WHEN t.points < 350 THEN 'Tree'
        ELSE 'Forest Guardian'
      END AS student_level_title,
      p.id AS account_id
    FROM totals AS t
    JOIN public.profiles AS p ON p.id = t.user_id
    JOIN auth.users AS u ON u.id = t.user_id
    WHERE t.points > 0
      AND COALESCE(p.is_test, false) = false
      AND COALESCE((u.raw_app_meta_data->>'is_test')::boolean, false) = false
      AND COALESCE((u.raw_user_meta_data->>'is_test')::boolean, false) = false
  )
  SELECT r.position, r.student_name, r.points, r.student_level, r.student_level_title, r.account_id
  FROM ranked AS r
  WHERE r.position <= LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100)
    AND (SELECT auth.uid()) IS NOT NULL
  ORDER BY r.position;
$function$;

REVOKE ALL ON FUNCTION public.get_campus_leaderboard(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_campus_leaderboard(integer) TO authenticated;

-- 6. Cleanup temporary audit helper functions
DROP FUNCTION IF EXISTS public.audit_leaderboard_accounts();
DROP FUNCTION IF EXISTS public.audit_user_events_and_reports();
