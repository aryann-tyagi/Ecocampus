
alter table public.floors
  add constraint floors_id_building_id_unique unique (id, building_id);

alter table public.areas
  add constraint areas_id_floor_id_unique unique (id, floor_id);

alter table public.reports
  add column building_id uuid references public.buildings(id) on delete restrict,
  add column floor_id uuid,
  add column floor_text text,
  add column location_details text;

-- There are currently no reports, so make the new canonical location fields required.
alter table public.reports
  alter column building_id set not null,
  alter column location_details set not null;

alter table public.reports
  add constraint reports_floor_building_fkey
    foreign key (floor_id, building_id) references public.floors(id, building_id) on delete restrict,
  add constraint reports_area_floor_fkey
    foreign key (area_id, floor_id) references public.areas(id, floor_id) on delete restrict,
  add constraint reports_floor_text_length_check
    check (floor_text is null or char_length(btrim(floor_text)) between 1 and 80),
  add constraint reports_location_details_length_check
    check (char_length(btrim(location_details)) between 2 and 255),
  add constraint reports_floor_selection_check
    check (floor_id is null or floor_text is null),
  add constraint reports_area_requires_floor_check
    check (area_id is null or floor_id is not null);

alter table public.reports
  alter column area_id drop not null;

create index reports_building_created_idx on public.reports (building_id, created_at desc);
create index reports_floor_id_idx on public.reports (floor_id) where floor_id is not null;

drop policy "Students can create their own initial reports" on public.reports;

create policy "Students can create their own initial reports"
  on public.reports for insert to authenticated
  with check (
    (select auth.uid()) = reporter_id
    and status = 'REPORTED'::public.ecocampus_report_status
    and exists (
      select 1 from public.buildings b
      where b.id = building_id and b.active
    )
    and (
      floor_id is null
      or exists (
        select 1 from public.floors f
        where f.id = floor_id
          and f.building_id = building_id
          and f.active
      )
    )
    and (
      area_id is null
      or exists (
        select 1 from public.areas a
        where a.id = area_id
          and a.floor_id = floor_id
          and a.active
      )
    )
  );
