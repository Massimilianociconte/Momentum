-- Trigger functions execute in the caller's context, but pinning the lookup
-- path still prevents object-shadowing if additional schemas are introduced.
alter function public.duo_sessions_guard()
  set search_path = public, pg_temp;
