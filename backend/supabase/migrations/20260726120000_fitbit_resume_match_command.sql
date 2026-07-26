-- RESUME_MATCH: mid-match handoff to Fitbit carrying the full phone journal.
-- The phone never talks to the watch directly, so resuming a paused match on
-- the Fitbit needs a dedicated outbound command through the gateway.
--
-- Payload limit grows from 8 KiB to 48 KiB: the gateway caps resume journals
-- at 250 sanitized events (~180 B each ≈ 45 KB), still well below the edge
-- function body limit. START_MATCH/REQUEST_STATE payloads stay tiny.

alter table public.wearable_outbound_commands
  drop constraint if exists wearable_outbound_commands_command_type_check;

alter table public.wearable_outbound_commands
  add constraint wearable_outbound_commands_command_type_check
  check (command_type in ('START_MATCH', 'REQUEST_STATE', 'RESUME_MATCH'));

alter table public.wearable_outbound_commands
  drop constraint if exists wearable_outbound_commands_payload_check;

alter table public.wearable_outbound_commands
  add constraint wearable_outbound_commands_payload_check
  check (pg_column_size(payload) <= 49152);
