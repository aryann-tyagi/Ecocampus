
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'report-photos',
  'report-photos',
  false,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp']
);
