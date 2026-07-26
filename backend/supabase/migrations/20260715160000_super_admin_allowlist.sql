-- Allowlist super admin DB-side per gli account owner. Indipendente dal
-- provider di autenticazione: conta solo l'email in auth.users, quindi vale
-- sia per registrazione email/password sia per Google OAuth. Copre:
--   1. utenti GIÀ registrati (grant immediato nel DO $$ in coda);
--   2. registrazioni FUTURE (trigger after insert su auth.users).
-- Complementare all'allowlist RALLYMATE_SUPER_ADMIN_EMAILS della edge
-- function assistant (che promuove solo al primo uso dell'assistente).

create table if not exists private.super_admin_allowlist (
  email text primary key check (email = lower(email))
);

revoke all on table private.super_admin_allowlist
  from public, anon, authenticated;

-- La tabella resta intenzionalmente vuota nel version control: gli indirizzi
-- owner sono dati privati e vanno inseriti dal SQL editor dopo il deploy:
-- insert into private.super_admin_allowlist (email)
-- values (lower('<owner-email>'))
-- on conflict (email) do nothing;

create or replace function private.apply_super_admin_allowlist()
returns trigger
language plpgsql
security definer
set search_path = public, private, auth
as $$
begin
  if new.email is not null
     and exists (
       select 1 from private.super_admin_allowlist a
       where a.email = lower(new.email)
     ) then
    begin
      perform public.grant_super_admin_by_email(new.email, 'owner allowlist');
    exception when others then
      -- Mai bloccare una signup per un grant fallito: warning e continua.
      raise warning 'super_admin allowlist grant failed for %: %',
        new.email, sqlerrm;
    end;
  end if;
  return new;
end;
$$;

revoke all on function private.apply_super_admin_allowlist() from public, anon;

drop trigger if exists apply_super_admin_allowlist on auth.users;
create trigger apply_super_admin_allowlist
  after insert on auth.users
  for each row execute function private.apply_super_admin_allowlist();

-- Grant immediato per chi risulta già registrato (con qualunque provider).
do $$
declare
  v_email text;
begin
  for v_email in
    select u.email
    from auth.users u
    join private.super_admin_allowlist a on a.email = lower(u.email)
  loop
    perform public.grant_super_admin_by_email(v_email, 'owner allowlist');
  end loop;
end;
$$;
