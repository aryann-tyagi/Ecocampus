
drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;

create index report_media_uploader_idx
  on public.report_media (uploader_id);

create index report_status_events_actor_idx
  on public.report_status_events (actor_id);

create index reports_suggested_department_idx
  on public.reports (suggested_department_id)
  where suggested_department_id is not null;
