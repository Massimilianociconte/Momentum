-- Scope wearable idempotency to the account. Provider-only uniqueness allows
-- an accidental or hostile cross-account event-id collision to drop a valid
-- event before the owner phone can recover it.

alter table public.wearable_ingest_events
  drop constraint if exists wearable_ingest_events_provider_external_event_id_key;

alter table public.wearable_ingest_events
  add constraint wearable_ingest_events_owner_provider_external_event_id_key
  unique (user_id, provider, external_event_id);
