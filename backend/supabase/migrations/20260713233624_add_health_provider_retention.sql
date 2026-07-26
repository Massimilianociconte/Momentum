-- Provider health data is deliberately bounded: token connections live until
-- revocation, while imported aggregates and delivery/audit rows expire.
create index if not exists health_metric_cloud_retention_idx
  on public.health_metric_records(provider, end_time)
  where provider in ('OURA_DIRECT', 'WHOOP_DIRECT');

create or replace function public.cleanup_health_provider_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_google_daily bigint;
  v_direct_summaries bigint;
  v_direct_metrics bigint;
  v_webhooks bigint;
  v_jobs bigint;
begin
  delete from public.wearable_daily_health_summaries
  where local_date < current_date - 30;
  get diagnostics v_google_daily = row_count;

  delete from public.match_health_summaries m
  using public.health_data_sources s
  where m.primary_source_id = s.source_id
    and s.provider in ('OURA_DIRECT', 'WHOOP_DIRECT')
    and m.calculated_at < now() - interval '30 days';
  get diagnostics v_direct_summaries = row_count;

  delete from public.health_metric_records
  where provider in ('OURA_DIRECT', 'WHOOP_DIRECT')
    and end_time < now() - interval '30 days';
  get diagnostics v_direct_metrics = row_count;

  delete from public.health_provider_webhook_events
  where received_at < now() - interval '30 days';
  get diagnostics v_webhooks = row_count;

  delete from public.health_sync_jobs
  where status in ('COMPLETED', 'FAILED')
    and coalesce(completed_at, created_at) < now() - interval '30 days';
  get diagnostics v_jobs = row_count;

  return jsonb_build_object(
    'google_daily_summaries', v_google_daily,
    'direct_match_summaries', v_direct_summaries,
    'direct_metric_records', v_direct_metrics,
    'provider_webhooks', v_webhooks,
    'provider_sync_jobs', v_jobs
  );
end;
$$;

comment on function public.cleanup_health_provider_data() is
  'Daily 30-day retention for cloud health aggregates and provider transport metadata.';

revoke all on function public.cleanup_health_provider_data() from public;
revoke all on function public.cleanup_health_provider_data()
  from anon, authenticated;
grant execute on function public.cleanup_health_provider_data() to service_role;

do $$
begin
  if not exists (
    select 1 from pg_available_extensions where name = 'pg_cron'
  ) then
    raise notice
      'pg_cron unavailable: schedule cleanup_health_provider_data externally';
    return;
  end if;
  create extension if not exists pg_cron;
  if exists (
    select 1 from cron.job where jobname = 'rallymate-cleanup-health-provider'
  ) then
    perform cron.unschedule('rallymate-cleanup-health-provider');
  end if;
  perform cron.schedule(
    'rallymate-cleanup-health-provider',
    '23 3 * * *',
    'select public.cleanup_health_provider_data()'
  );
exception when others then
  raise notice 'health provider pg_cron not scheduled (%): use an external scheduler',
    sqlerrm;
end $$;
