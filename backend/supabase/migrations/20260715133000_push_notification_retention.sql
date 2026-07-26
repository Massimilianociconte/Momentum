-- Push transport data is operational audit, not product history. Keep at most
-- 30 days, then delete the outbox row and its delivery attempts in cascade.

create index if not exists push_outbox_retention_idx
  on public.push_outbox(created_at)
  where status in ('SENT', 'FAILED', 'SUPPRESSED', 'PARTIAL');

create or replace function public.cleanup_push_notifications()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_notifications bigint;
begin
  delete from public.push_outbox
  where created_at < now() - interval '30 days'
    and (
      status in ('SENT', 'FAILED', 'SUPPRESSED', 'PARTIAL')
      or expires_at < now()
    );
  get diagnostics v_notifications = row_count;

  return jsonb_build_object('push_notifications', v_notifications);
end;
$$;

comment on function public.cleanup_push_notifications() is
  'Deletes terminal or expired push outbox rows older than 30 days; delivery '
  'audit rows are removed by cascade. Scheduled daily when pg_cron exists.';

revoke all on function public.cleanup_push_notifications() from public;
revoke all on function public.cleanup_push_notifications()
  from anon, authenticated;
grant execute on function public.cleanup_push_notifications() to service_role;

do $$
begin
  if not exists (
    select 1 from pg_available_extensions where name = 'pg_cron'
  ) then
    raise notice
      'pg_cron unavailable: schedule cleanup_push_notifications() externally';
    return;
  end if;

  create extension if not exists pg_cron;
  if exists (
    select 1 from cron.job where jobname = 'rallymate-cleanup-push'
  ) then
    perform cron.unschedule('rallymate-cleanup-push');
  end if;
  perform cron.schedule(
    'rallymate-cleanup-push',
    '29 3 * * *',
    'select public.cleanup_push_notifications()'
  );
exception when others then
  raise notice 'push cleanup pg_cron not scheduled (%): use an external scheduler',
    sqlerrm;
end $$;
