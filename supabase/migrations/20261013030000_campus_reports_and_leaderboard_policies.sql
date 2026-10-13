-- EcoCampus Migration: Campus Reports Shared Feed & Leaderboard Access
-- Enables authenticated students to view active campus reports for the shared nearby issues feed.
-- Strictly preserves student ownership isolation: private media and internal status events remain author-scoped.

-- 1. Active Campus Reports Read Policy
-- Allows authenticated students to discover active campus issues across buildings.
-- Reports with status REJECTED or DUPLICATE are excluded from public discovery.
DROP POLICY IF EXISTS "Authenticated users can view campus reports" ON public.reports;
CREATE POLICY "Authenticated users can view campus reports"
  ON public.reports FOR SELECT TO authenticated
  USING (status NOT IN ('REJECTED', 'DUPLICATE'));

-- 2. Ensure public.profiles is readable by authenticated users for displaying leaderboard names
DROP POLICY IF EXISTS "Authenticated users can view profiles" ON public.profiles;
CREATE POLICY "Authenticated users can view profiles"
  ON public.profiles FOR SELECT TO authenticated
  USING (true);
