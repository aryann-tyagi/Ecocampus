-- EcoCampus Migration: Reports, Location Hierarchy & Media Privileges
-- Reconciles remote schema state and grants required permissions to authenticated students.

-- 1. Ensure table-level permissions for authenticated users
GRANT SELECT ON TABLE public.buildings TO authenticated;
GRANT SELECT ON TABLE public.floors TO authenticated;
GRANT SELECT ON TABLE public.areas TO authenticated;
GRANT SELECT ON TABLE public.departments TO authenticated;
GRANT SELECT, INSERT ON TABLE public.reports TO authenticated;
GRANT SELECT, INSERT ON TABLE public.report_media TO authenticated;
GRANT SELECT ON TABLE public.report_status_events TO authenticated;

-- 2. Ensure Row Level Security (RLS) is active
ALTER TABLE public.buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.floors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_status_events ENABLE ROW LEVEL SECURITY;

-- 3. Buildings / Floors / Areas / Departments Read Policies
DROP POLICY IF EXISTS "Allow authenticated read buildings" ON public.buildings;
CREATE POLICY "Allow authenticated read buildings"
  ON public.buildings FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated read floors" ON public.floors;
CREATE POLICY "Allow authenticated read floors"
  ON public.floors FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated read areas" ON public.areas;
CREATE POLICY "Allow authenticated read areas"
  ON public.areas FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated read departments" ON public.departments;
CREATE POLICY "Allow authenticated read departments"
  ON public.departments FOR SELECT TO authenticated USING (true);

-- 4. Reports RLS Policies: Students can insert and read their own reports
DROP POLICY IF EXISTS "Students can view own reports" ON public.reports;
CREATE POLICY "Students can view own reports"
  ON public.reports FOR SELECT TO authenticated
  USING (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "Students can insert own reports" ON public.reports;
CREATE POLICY "Students can insert own reports"
  ON public.reports FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reporter_id);

-- 5. Report Media RLS Policies: Students can insert and read their own media
DROP POLICY IF EXISTS "Users can view own report media" ON public.report_media;
CREATE POLICY "Users can view own report media"
  ON public.report_media FOR SELECT TO authenticated
  USING (auth.uid() = uploader_id);

DROP POLICY IF EXISTS "Users can insert own report media" ON public.report_media;
CREATE POLICY "Users can insert own report media"
  ON public.report_media FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = uploader_id);

-- 6. Report Status Events RLS Policies
DROP POLICY IF EXISTS "Students can view own report status events" ON public.report_status_events;
CREATE POLICY "Students can view own report status events"
  ON public.report_status_events FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.reports
      WHERE reports.id = report_status_events.report_id
        AND reports.reporter_id = auth.uid()
    )
  );
