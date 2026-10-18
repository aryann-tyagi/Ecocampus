
ALTER FUNCTION public.get_my_eco_stats() SECURITY INVOKER;
REVOKE ALL ON FUNCTION public.get_my_eco_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_eco_stats() TO authenticated;
NOTIFY pgrst, 'reload schema';
