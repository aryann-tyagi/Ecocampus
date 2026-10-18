
insert into public.buildings (name, slug, active)
values
  ('Engineering Block', 'engineering-block', true),
  ('New Engineering Block', 'new-engineering-block', true),
  ('Hotel Management Block', 'hotel-management-block', true),
  ('Old Law Block', 'old-law-block', true),
  ('Boys Hostel', 'boys-hostel', true),
  ('Girls Hostel', 'girls-hostel', true),
  ('Hostel Mess', 'hostel-mess', true),
  ('Royals Cafe', 'royals-cafe', true),
  ('Cafeteria', 'cafeteria', true),
  ('Sports Complex', 'sports-complex', true),
  ('Hostel Ground', 'hostel-ground', true),
  ('Bus Parking', 'bus-parking', true),
  ('Library', 'library', true),
  ('Law Library', 'law-library', true)
on conflict (slug) do update
set name = excluded.name, active = true;

insert into public.floors (building_id, label, sort_order, active)
select b.id, floor_data.label, floor_data.sort_order, true
from public.buildings b
join (
  values
    ('engineering-block', 'Basement', -1),
    ('engineering-block', 'Ground Floor', 0),
    ('engineering-block', 'First Floor', 1),
    ('engineering-block', 'Second Floor', 2),
    ('engineering-block', 'Third Floor', 3),
    ('engineering-block', 'Fourth Floor', 4),
    ('new-engineering-block', 'Basement', -1),
    ('new-engineering-block', 'Ground Floor', 0),
    ('new-engineering-block', 'First Floor', 1),
    ('new-engineering-block', 'Second Floor', 2),
    ('new-engineering-block', 'Third Floor', 3),
    ('new-engineering-block', 'Fourth Floor', 4),
    ('new-engineering-block', 'Fifth Floor', 5),
    ('new-engineering-block', 'Auditorium', 6)
) as floor_data(building_slug, label, sort_order)
  on floor_data.building_slug = b.slug
on conflict (building_id, label) do nothing;
