
revoke insert on table public.reports from authenticated;
grant insert (
  reporter_id, area_id, category, severity, issue_label, description,
  suggested_department_id, latitude, longitude
) on table public.reports to authenticated;

revoke insert on table public.report_media from authenticated;
grant insert (
  report_id, uploader_id, storage_path, mime_type, position
) on table public.report_media to authenticated;

drop policy "EcoCampus users can delete their own report photos" on storage.objects;

create policy "EcoCampus users can delete unlinked report photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not exists (
      select 1
      from public.report_media rm
      where rm.storage_path = name
    )
  );
