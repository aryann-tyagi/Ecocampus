
-- Remove duplicate or weaker policies added outside the original migrations.
drop policy if exists "Students can insert own reports" on public.reports;
drop policy if exists "Students can view own reports" on public.reports;
drop policy if exists "Users can insert own report media" on public.report_media;
drop policy if exists "Users can view own report media" on public.report_media;

-- Replace the initial-report policy with properly correlated parent/child checks.
drop policy if exists "Students can create their own initial reports" on public.reports;

create policy "Students can create their own initial reports"
  on public.reports
  for insert
  to authenticated
  with check (
    reporter_id = (select auth.uid())
    and status = 'REPORTED'::public.ecocampus_report_status
    and exists (
      select 1
      from public.buildings b
      where b.id = reports.building_id
        and b.active
    )
    and (
      reports.floor_id is null
      or exists (
        select 1
        from public.floors f
        where f.id = reports.floor_id
          and f.building_id = reports.building_id
          and f.active
      )
    )
    and (
      reports.area_id is null
      or exists (
        select 1
        from public.areas a
        where a.id = reports.area_id
          and a.floor_id = reports.floor_id
          and a.active
      )
    )
  );

-- Prevent ambiguous media metadata rows for another user's report or path.
drop policy if exists "Students can attach media to their own reports" on public.report_media;

create policy "Students can attach media to their own reports"
  on public.report_media
  for insert
  to authenticated
  with check (
    uploader_id = (select auth.uid())
    and (storage.foldername(storage_path))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.reports r
      where r.id = report_media.report_id
        and r.reporter_id = (select auth.uid())
    )
  );
