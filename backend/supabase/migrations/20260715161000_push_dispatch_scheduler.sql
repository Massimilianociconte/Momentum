-- Scheduler dell'outbox push: pg_cron invoca la edge function push-dispatch
-- via pg_net, autenticandosi con l'header X-RallyMate-Push-Secret.
--
-- URL e secret NON stanno in questa migrazione (finirebbero nel repo): si
-- leggono da Vault, da seedare una volta per ambiente dal SQL editor:
--   select vault.create_secret('<https://.../functions/v1/push-dispatch>', 'push_dispatch_url');
--   select vault.create_secret('<PUSH_DISPATCH_SECRET>', 'push_dispatch_secret');
-- Senza seed (es. stack locale/CI) la funzione è un no-op silenzioso.

do $$
begin
  if exists (
    select 1 from pg_available_extensions where name = 'pg_net'
  ) then
    create extension if not exists pg_net;
  else
    raise notice 'pg_net unavailable: invoke push-dispatch externally';
  end if;
end;
$$;

create or replace function private.invoke_push_dispatch()
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_url text;
  v_secret text;
begin
  -- Niente lavoro in coda → niente chiamata HTTP: il tick ogni pochi
  -- secondi resta a costo zero quando l'outbox è vuota. I PROCESSING
  -- stantii (dispatcher morto a metà) contano come lavoro da reclamare.
  if not exists (
    select 1 from public.push_outbox
    where (status in ('PENDING', 'RETRY') and next_attempt_at <= now())
       or (status = 'PROCESSING'
           and claimed_at < now() - interval '5 minutes')
  ) then
    return;
  end if;

  select decrypted_secret into v_url
  from vault.decrypted_secrets
  where name = 'push_dispatch_url'
  order by created_at desc
  limit 1;
  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'push_dispatch_secret'
  order by created_at desc
  limit 1;
  if v_url is null or v_secret is null then
    return;
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-RallyMate-Push-Secret', v_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 10000
  );
end;
$$;

revoke all on function private.invoke_push_dispatch()
  from public, anon, authenticated;

do $$
begin
  if not exists (
    select 1 from pg_available_extensions where name = 'pg_cron'
  ) then
    raise notice 'pg_cron unavailable: schedule invoke_push_dispatch() externally';
    return;
  end if;
  create extension if not exists pg_cron;
  if exists (
    select 1 from cron.job where jobname = 'rallymate-push-dispatch'
  ) then
    perform cron.unschedule('rallymate-push-dispatch');
  end if;
  perform cron.schedule(
    'rallymate-push-dispatch',
    '10 seconds',
    'select private.invoke_push_dispatch()'
  );
end;
$$;
