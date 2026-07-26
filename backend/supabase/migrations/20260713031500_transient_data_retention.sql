-- Retention dei dati transitori (igiene server, costi e tempi di query).
--
-- Nessuna di queste tabelle è fonte di verità del prodotto: sono transport
-- (inbox wearable già ACKate dal telefono), anti-abuso (finestre di rate
-- limit al massimo di minuti), sfide di pairing monouso o sessioni Duo
-- concluse la cui partita vive nello storico locale/backup dell'utente.
-- Senza pulizia crescono per sempre; con la pulizia le finestre operative
-- restano ampiamente coperte:
--   * rate events:            7 giorni   (finestre reali: 1-10 minuti)
--   * pairing/oauth scaduti:  1 giorno   (TTL reale: 10-15 minuti)
--   * ingest ACKati:          30 giorni  (già commit su telefono + ACK)
--   * comandi chiusi/scaduti: 30 giorni  (TTL massimo: 24 ore)
--   * notifiche processate:   30 giorni
--   * sessioni Duo chiuse:    90 giorni  (eventi in cascade; la partita
--                                         resta nello storico locale)
--   * sessioni Duo mai attivate: 30 giorni dopo la scadenza del codice
--   * assistant_queries:      180 giorni (cache riusa solo gli ultimi 30)

-- Delete mirato sugli ACKati vecchi senza scandire l'inbox attiva.
create index if not exists wearable_ingest_events_acked_idx
  on public.wearable_ingest_events (acknowledged_at)
  where acknowledged_at is not null;

create or replace function public.cleanup_transient_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rate bigint;
  v_pairing bigint;
  v_oauth bigint;
  v_ingest bigint;
  v_commands bigint;
  v_notifications bigint;
  v_duo_closed bigint;
  v_duo_stale bigint;
  v_assistant bigint;
begin
  delete from public.wearable_gateway_rate_events
  where created_at < now() - interval '7 days';
  get diagnostics v_rate = row_count;

  delete from public.wearable_pairing_challenges
  where (consumed_at is not null or expires_at < now())
    and created_at < now() - interval '1 day';
  get diagnostics v_pairing = row_count;

  delete from public.wearable_oauth_states
  where (consumed_at is not null or expires_at < now())
    and created_at < now() - interval '1 day';
  get diagnostics v_oauth = row_count;

  delete from public.wearable_ingest_events
  where acknowledged_at is not null
    and acknowledged_at < now() - interval '30 days';
  get diagnostics v_ingest = row_count;

  delete from public.wearable_outbound_commands
  where (acknowledged_at is not null or expires_at < now())
    and created_at < now() - interval '30 days';
  get diagnostics v_commands = row_count;

  delete from public.wearable_health_notifications
  where processed_at is not null
    and processed_at < now() - interval '30 days';
  get diagnostics v_notifications = row_count;

  delete from public.duo_sessions
  where status in ('COMPLETED', 'CANCELLED')
    and updated_at < now() - interval '90 days';
  get diagnostics v_duo_closed = row_count;

  -- Sessioni create ma mai attivate: il codice è scaduto da settimane e
  -- nessun guest è mai entrato.
  delete from public.duo_sessions
  where status = 'PENDING'
    and guest_id is null
    and code_expires_at < now() - interval '30 days';
  get diagnostics v_duo_stale = row_count;

  delete from public.assistant_queries
  where created_at < now() - interval '180 days';
  get diagnostics v_assistant = row_count;

  return jsonb_build_object(
    'rate_events', v_rate,
    'pairing_challenges', v_pairing,
    'oauth_states', v_oauth,
    'ingest_events', v_ingest,
    'outbound_commands', v_commands,
    'health_notifications', v_notifications,
    'duo_sessions_closed', v_duo_closed,
    'duo_sessions_stale', v_duo_stale,
    'assistant_queries', v_assistant
  );
end;
$$;

comment on function public.cleanup_transient_data() is
  'Retention giornaliera dei dati transitori. Idempotente; schedulata via '
  'pg_cron (rallymate-cleanup-transient) o invocabile dal service role.';

revoke all on function public.cleanup_transient_data() from public;
revoke all on function public.cleanup_transient_data()
  from anon, authenticated;
grant execute on function public.cleanup_transient_data() to service_role;

-- Pianificazione notturna. pg_cron è disponibile sui progetti Supabase
-- hosted; in locale (o dove manca) la migrazione resta valida e la funzione
-- può essere invocata da uno scheduler esterno.
do $$
begin
  if not exists (
    select 1 from pg_available_extensions where name = 'pg_cron'
  ) then
    raise notice
      'pg_cron non disponibile: schedulare cleanup_transient_data() esternamente';
    return;
  end if;
  create extension if not exists pg_cron;
  if exists (
    select 1 from cron.job where jobname = 'rallymate-cleanup-transient'
  ) then
    perform cron.unschedule('rallymate-cleanup-transient');
  end if;
  perform cron.schedule(
    'rallymate-cleanup-transient',
    '17 3 * * *',
    'select public.cleanup_transient_data()'
  );
exception when others then
  raise notice 'pg_cron non pianificato (%): usare uno scheduler esterno',
    sqlerrm;
end $$;
