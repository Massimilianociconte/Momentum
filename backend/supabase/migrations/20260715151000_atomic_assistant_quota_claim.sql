-- La edge function assistant faceva count-then-insert in due richieste
-- separate: N chiamate parallele passavano tutte il check del limite
-- giornaliero/live e ogni sforo era una chiamata DeepSeek pagata. Il claim
-- ora è atomico: advisory lock per utente + count + insert della riga
-- (answer null) nella stessa transazione. La edge function poi aggiorna la
-- riga con la risposta, o la elimina se l'LLM fallisce (rimborso quota).
--
-- Le righe pending (answer null) non inquinano la cache: la lookup filtra
-- già con answer not null.

create or replace function public.claim_assistant_slot(
  p_match_id text,
  p_mode text,
  p_question text,
  p_question_hash text,
  p_user_id uuid,
  p_daily_limit int,
  p_live_limit int
)
returns table (query_id uuid, reason text, used_today int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_used_today int;
  v_live_used int;
  v_query_id uuid;
begin
  -- Serializza i claim concorrenti dello stesso utente: senza lock due
  -- richieste parallele leggono lo stesso count e superano il limite.
  perform pg_advisory_xact_lock(
    hashtextextended('assistant_quota:' || p_user_id::text, 0)
  );

  select count(*) into v_used_today
  from public.assistant_queries
  where user_id = p_user_id
    and created_at >= (date_trunc('day', now() at time zone 'utc') at time zone 'utc');

  if v_used_today >= p_daily_limit then
    return query select null::uuid, 'daily_limit'::text, v_used_today;
    return;
  end if;

  if p_mode = 'LIVE_MATCH' and p_match_id is not null then
    select count(*) into v_live_used
    from public.assistant_queries
    where user_id = p_user_id
      and match_id = p_match_id
      and mode = 'LIVE_MATCH';
    if v_live_used >= p_live_limit then
      return query select null::uuid, 'live_limit'::text, v_used_today;
      return;
    end if;
  end if;

  insert into public.assistant_queries (user_id, match_id, mode, question, question_hash)
  values (p_user_id, p_match_id, p_mode, p_question, p_question_hash)
  returning assistant_queries.query_id into v_query_id;

  return query select v_query_id, null::text, v_used_today;
end;
$$;

-- Solo la edge function (service role) può reclamare slot: il client non
-- scrive mai su assistant_queries.
revoke all on function public.claim_assistant_slot(
  text, text, text, text, uuid, int, int
) from public, anon, authenticated;
grant execute on function public.claim_assistant_slot(
  text, text, text, text, uuid, int, int
) to service_role;
