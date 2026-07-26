-- coach_packages.commission_rate era scritto dal client senza vincoli: un
-- coach con client modificato (o PostgREST diretto) poteva impostare rate 0
-- o negativo e azzerare/invertire la commissione calcolata da coach-checkout.
-- Il rate ora è derivato lato server dal tipo pacchetto (PRD I3: 15%
-- digitale, 10% live) tramite trigger; il CHECK resta come difesa in
-- profondità contro scritture che bypassassero il trigger.

create or replace function private.coach_commission_rate(p_type text)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when p_type in ('LIVE_1TO1', 'GROUP_LESSON') then 0.100
    else 0.150
  end;
$$;

revoke all on function private.coach_commission_rate(text) from public, anon;
grant execute on function private.coach_commission_rate(text)
  to authenticated, service_role;

-- Riallinea le righe esistenti prima di aggiungere trigger e CHECK.
update public.coach_packages
set commission_rate = private.coach_commission_rate(type)
where commission_rate is distinct from private.coach_commission_rate(type);

create or replace function private.enforce_coach_package_commission()
returns trigger
language plpgsql
set search_path = public, private
as $$
begin
  new.commission_rate := private.coach_commission_rate(new.type);
  return new;
end;
$$;

drop trigger if exists coach_packages_enforce_commission on public.coach_packages;
create trigger coach_packages_enforce_commission
  before insert or update on public.coach_packages
  for each row execute function private.enforce_coach_package_commission();

alter table public.coach_packages
  drop constraint if exists coach_packages_commission_rate_check;
alter table public.coach_packages
  add constraint coach_packages_commission_rate_check
  check (commission_rate >= 0.050 and commission_rate <= 0.300);
