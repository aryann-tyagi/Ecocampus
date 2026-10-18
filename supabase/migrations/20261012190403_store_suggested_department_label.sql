
alter table public.reports
  add column suggested_department_label text
    check (
      suggested_department_label is null
      or char_length(btrim(suggested_department_label)) between 1 and 100
    );
