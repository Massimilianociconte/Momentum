-- Funzioni di supporto.

-- Contatore visualizzazioni recap (chiamata dalla edge function `recap`).
create or replace function public.increment_card_views(p_card_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.wrapped_cards
  set view_count = view_count + 1
  where card_id = p_card_id;
$$;

revoke all on function public.increment_card_views(uuid) from public;

-- Webhook RevenueCat → aggiornamento piano (chiamata con service role da
-- una edge function dedicata o da RevenueCat direct webhook).
create or replace function public.set_plan(
  p_user_id uuid,
  p_plan text,
  p_expires_at timestamptz
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles
  set plan = p_plan, plan_expires_at = p_expires_at
  where user_id = p_user_id;
$$;

revoke all on function public.set_plan(uuid, text, timestamptz) from public;
