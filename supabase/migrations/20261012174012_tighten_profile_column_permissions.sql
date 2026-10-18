
revoke update on table public.profiles from authenticated;
grant update (display_name, companion_name, avatar_url)
  on table public.profiles to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  derived_display_name text;
begin
  derived_display_name := pg_catalog.left(
    coalesce(
      nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(pg_catalog.split_part(coalesce(new.email, ''), '@', 1), ''),
      'Student'
    ),
    80
  );

  insert into public.profiles (id, display_name)
  values (new.id, derived_display_name);

  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
