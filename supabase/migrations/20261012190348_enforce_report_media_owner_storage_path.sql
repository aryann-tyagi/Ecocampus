
drop policy "Students can attach media to their own reports" on public.report_media;

create policy "Students can attach media to their own reports"
  on public.report_media for insert to authenticated
  with check (
    uploader_id = (select auth.uid())
    and (storage.foldername(storage_path))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.reports r
      where r.id = report_id and r.reporter_id = (select auth.uid())
    )
  );
