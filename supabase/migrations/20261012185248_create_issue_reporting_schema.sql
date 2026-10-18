
create type public.ecocampus_issue_category as enum (
  'waste', 'water', 'electricity', 'infrastructure', 'greenery', 'cleanliness', 'other'
);

create type public.ecocampus_issue_severity as enum (
  'low', 'medium', 'high', 'critical'
);

create type public.ecocampus_report_status as enum (
  'REPORTED', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED'
);

create table public.departments (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(btrim(name)) between 2 and 100),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.buildings (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.floors (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.buildings(id) on delete restrict,
  label text not null check (char_length(btrim(label)) between 1 and 80),
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (building_id, label)
);

create table public.areas (
  id uuid primary key default gen_random_uuid(),
  floor_id uuid not null references public.floors(id) on delete restrict,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (floor_id, name)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete restrict,
  area_id uuid not null references public.areas(id) on delete restrict,
  category public.ecocampus_issue_category not null,
  severity public.ecocampus_issue_severity not null,
  issue_label text check (issue_label is null or char_length(btrim(issue_label)) between 1 and 160),
  description text not null check (char_length(btrim(description)) > 0),
  suggested_department_id uuid references public.departments(id) on delete set null,
  status public.ecocampus_report_status not null default 'REPORTED',
  latitude double precision check (latitude is null or latitude between -90 and 90),
  longitude double precision check (longitude is null or longitude between -180 and 180),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null) = (longitude is null))
);

create index reports_reporter_created_idx on public.reports (reporter_id, created_at desc);
create index reports_status_severity_created_idx on public.reports (status, severity, created_at desc);
create index reports_area_category_created_idx on public.reports (area_id, category, created_at desc);

create table public.report_media (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  uploader_id uuid not null references auth.users(id) on delete restrict,
  storage_path text not null unique check (char_length(storage_path) between 1 and 1024),
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  position smallint not null default 0 check (position between 0 and 2),
  created_at timestamptz not null default now(),
  unique (report_id, position)
);

create index report_media_report_idx on public.report_media (report_id, position);

create table public.report_status_events (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  from_status public.ecocampus_report_status,
  to_status public.ecocampus_report_status not null,
  actor_id uuid references auth.users(id) on delete set null,
  note text,
  occurred_at timestamptz not null default now(),
  check (from_status is null or from_status <> to_status)
);

create index report_status_events_report_time_idx on public.report_status_events (report_id, occurred_at asc);

-- Reference data is readable to authenticated users, but client writes are not granted.
alter table public.departments enable row level security;
alter table public.buildings enable row level security;
alter table public.floors enable row level security;
alter table public.areas enable row level security;

grant select on public.departments, public.buildings, public.floors, public.areas to authenticated;

create policy "Authenticated users can read active departments"
  on public.departments for select to authenticated using (active);

create policy "Authenticated users can read active buildings"
  on public.buildings for select to authenticated using (active);

create policy "Authenticated users can read floors in active buildings"
  on public.floors for select to authenticated
  using (
    active and exists (
      select 1 from public.buildings b
      where b.id = building_id and b.active
    )
  );

create policy "Authenticated users can read areas on active floors"
  on public.areas for select to authenticated
  using (
    active and exists (
      select 1
      from public.floors f
      join public.buildings b on b.id = f.building_id
      where f.id = floor_id and f.active and b.active
    )
  );

-- Reporters can create and read only their own reports.
-- They cannot directly update status, severity, department assignment, or delete reports.
alter table public.reports enable row level security;
grant select, insert on public.reports to authenticated;

create policy "Students can read their own reports"
  on public.reports for select to authenticated
  using ((select auth.uid()) = reporter_id);

create policy "Students can create their own initial reports"
  on public.reports for insert to authenticated
  with check (
    (select auth.uid()) = reporter_id
    and status = 'REPORTED'::public.ecocampus_report_status
  );

-- Photo metadata is visible only to the report owner. Media rows cannot be changed after insert.
alter table public.report_media enable row level security;
grant select, insert on public.report_media to authenticated;

create policy "Students can read media for their own reports"
  on public.report_media for select to authenticated
  using (
    uploader_id = (select auth.uid())
    and exists (
      select 1 from public.reports r
      where r.id = report_id and r.reporter_id = (select auth.uid())
    )
  );

create policy "Students can attach media to their own reports"
  on public.report_media for insert to authenticated
  with check (
    uploader_id = (select auth.uid())
    and exists (
      select 1 from public.reports r
      where r.id = report_id and r.reporter_id = (select auth.uid())
    )
  );

-- Status history is append-only to application clients. A trusted trigger records the initial state.
alter table public.report_status_events enable row level security;
grant select on public.report_status_events to authenticated;

create policy "Students can read status history for their own reports"
  on public.report_status_events for select to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = report_id and r.reporter_id = (select auth.uid())
    )
  );

create or replace function public.set_report_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

create trigger set_reports_updated_at
  before update on public.reports
  for each row
  execute function public.set_report_updated_at();

create or replace function public.record_initial_report_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.report_status_events (
    report_id, from_status, to_status, actor_id, note
  ) values (
    new.id, null, new.status, new.reporter_id, 'Report submitted'
  );
  return new;
end;
$$;

revoke execute on function public.record_initial_report_status() from public, anon, authenticated;

create trigger record_initial_report_status_after_insert
  after insert on public.reports
  for each row
  execute function public.record_initial_report_status();

-- Private photo bucket object policies. Create the private bucket named report-photos in Storage
-- before uploads are attempted. Paths must begin with the authenticated user's UUID.
create policy "EcoCampus users can upload their own report photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "EcoCampus users can read their own report photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "EcoCampus users can delete their own report photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
