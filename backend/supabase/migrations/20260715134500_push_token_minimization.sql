-- Minimize raw APNs/FCM routing identifiers after opt-out. Client-triggered
-- deactivation removes the installation immediately; provider-invalidated
-- rows remain briefly for diagnostics and are purged after 30 days.

create index if not exists push_devices_disabled_retention_idx
  on public.push_devices(updated_at)
  where enabled = false;

create or replace function public.deactivate_my_push_device(
  p_installation_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_count int;
begin
  if v_uid is null then
    raise sqlstate '42501' using message = 'authentication required';
  end if;

  delete from public.push_devices
   where user_id = v_uid
     and installation_id = p_installation_id;
  get diagnostics v_count = row_count;

  return jsonb_build_object('ok', true, 'deactivated', v_count);
end;
$$;

revoke all on function public.deactivate_my_push_device(uuid) from public;
revoke all on function public.deactivate_my_push_device(uuid)
  from anon;
grant execute on function public.deactivate_my_push_device(uuid)
  to authenticated;

create or replace function public.cleanup_push_notifications()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_notifications bigint;
  v_devices bigint;
begin
  delete from public.push_outbox
  where created_at < now() - interval '30 days'
    and (
      status in ('SENT', 'FAILED', 'SUPPRESSED', 'PARTIAL')
      or expires_at < now()
    );
  get diagnostics v_notifications = row_count;

  delete from public.push_devices
  where enabled = false
    and updated_at < now() - interval '30 days';
  get diagnostics v_devices = row_count;

  return jsonb_build_object(
    'push_notifications', v_notifications,
    'push_devices', v_devices
  );
end;
$$;

revoke all on function public.cleanup_push_notifications() from public;
revoke all on function public.cleanup_push_notifications()
  from anon, authenticated;
grant execute on function public.cleanup_push_notifications() to service_role;
