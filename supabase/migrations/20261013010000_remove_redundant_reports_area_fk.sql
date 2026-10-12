-- The composite FK already enforces that a selected area belongs to the selected floor.
-- Keep one reports -> areas relationship so PostgREST embeddings are not ambiguous.
-- The existing reports_area_requires_floor_check prevents area_id without floor_id.
ALTER TABLE public.reports
  DROP CONSTRAINT IF EXISTS reports_area_id_fkey;
