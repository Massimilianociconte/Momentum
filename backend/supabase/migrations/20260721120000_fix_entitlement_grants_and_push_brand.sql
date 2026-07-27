-- Fix: RLS-facing entitlement helpers must be executable by authenticated
-- (policies invoke them as the invoker). Rebrand push templates to Momentum.

begin;

grant execute on function public.has_active_entitlement(uuid, text[])
  to authenticated, service_role;
grant execute on function public.has_cloud_media_access()
  to authenticated, service_role;
grant execute on function public.has_duo_access(uuid)
  to authenticated, service_role;
grant execute on function public.has_pro_access(uuid)
  to authenticated, service_role;

-- Best-effort rebrand of stored notification templates / pending titles.
-- Only updates known RallyMate copy; leaves custom payloads alone.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'push_outbox' and column_name = 'title'
  ) then
    update public.push_outbox
    set title = replace(title, 'RallyMate', 'Momentum'),
        body = replace(body, 'RallyMate', 'Momentum')
    where title ilike '%RallyMate%' or body ilike '%RallyMate%';
  end if;
exception when others then
  raise notice 'push_outbox brand update skipped: %', sqlerrm;
end $$;

commit;
