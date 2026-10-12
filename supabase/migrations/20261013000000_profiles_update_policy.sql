-- EcoCampus Migration: Profiles Update Grant & Row Level Security Policy
-- Fixes: PostgrestException 42501 (permission denied for table profiles on update)

-- 1. Grant table-level privileges on public.profiles to authenticated users
GRANT SELECT, UPDATE ON TABLE public.profiles TO authenticated;

-- 2. Ensure Row Level Security is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. Ensure authenticated users can select their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- 4. Allow authenticated users to update their own profile columns (display_name, companion_name, avatar_url, updated_at)
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
