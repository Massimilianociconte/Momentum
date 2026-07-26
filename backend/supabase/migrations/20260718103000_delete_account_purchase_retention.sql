begin;

-- An account deletion must remove personal/operational coach data without
-- destroying the minimum transaction record needed for refunds, disputes,
-- accounting and store anti-replay.  Snapshot package facts while the package
-- still exists, then detach the purchase from deleted identities.
alter table public.coach_purchases
  add column package_title_snapshot text,
  add column package_type_snapshot text,
  add column currency_snapshot text;

update public.coach_purchases purchase
set package_title_snapshot = package.title,
    package_type_snapshot = package.type,
    currency_snapshot = package.currency
from public.coach_packages package
where package.package_id = purchase.package_id;

alter table public.coach_purchases
  alter column package_title_snapshot set not null,
  alter column package_type_snapshot set not null,
  alter column currency_snapshot set not null;

create or replace function private.snapshot_coach_purchase_package()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_title text;
  v_type text;
  v_currency text;
begin
  -- ON DELETE SET NULL updates package_id after the commercial facts have
  -- already been snapshotted.  Preserve those facts when the FK is detached.
  if new.package_id is null then
    return new;
  end if;

  if tg_op = 'INSERT'
     or new.package_id is distinct from old.package_id
     or new.package_title_snapshot is null
     or new.package_type_snapshot is null
     or new.currency_snapshot is null then
    select package.title, package.type, package.currency
      into v_title, v_type, v_currency
    from public.coach_packages package
    where package.package_id = new.package_id;

    if not found then
      raise exception using
        errcode = '23503',
        message = 'coach package does not exist';
    end if;

    new.package_title_snapshot := v_title;
    new.package_type_snapshot := v_type;
    new.currency_snapshot := v_currency;
  end if;

  return new;
end;
$$;

drop trigger if exists coach_purchase_package_snapshot
  on public.coach_purchases;
create trigger coach_purchase_package_snapshot
before insert or update of package_id on public.coach_purchases
for each row execute function private.snapshot_coach_purchase_package();

-- Purchases survive account/package deletion, but no longer retain the UUID of
-- a deleted person.  Rows detached from both parties are inaccessible through
-- client RLS and remain service-side accounting records only.
alter table public.coach_purchases
  drop constraint if exists coach_purchases_package_id_fkey,
  drop constraint if exists coach_purchases_coach_id_fkey,
  drop constraint if exists coach_purchases_player_id_fkey,
  alter column package_id drop not null,
  alter column coach_id drop not null,
  alter column player_id drop not null,
  add constraint coach_purchases_package_id_fkey
    foreign key (package_id) references public.coach_packages(package_id)
    on delete set null,
  add constraint coach_purchases_coach_id_fkey
    foreign key (coach_id) references public.coach_profiles(coach_id)
    on delete set null,
  add constraint coach_purchases_player_id_fkey
    foreign key (player_id) references public.profiles(user_id)
    on delete set null;

-- Assignments are operational/personal content, not fiscal history.  Remove
-- them when either participant or the underlying purchase is deleted.
alter table public.coach_assignments
  drop constraint if exists coach_assignments_purchase_id_fkey,
  drop constraint if exists coach_assignments_coach_id_fkey,
  drop constraint if exists coach_assignments_player_id_fkey,
  add constraint coach_assignments_purchase_id_fkey
    foreign key (purchase_id) references public.coach_purchases(purchase_id)
    on delete cascade,
  add constraint coach_assignments_coach_id_fkey
    foreign key (coach_id) references public.coach_profiles(coach_id)
    on delete cascade,
  add constraint coach_assignments_player_id_fkey
    foreign key (player_id) references public.profiles(user_id)
    on delete cascade;

comment on column public.coach_purchases.package_title_snapshot is
  'Package title at purchase time; retained after account/package deletion.';
comment on column public.coach_purchases.package_type_snapshot is
  'Package type at purchase time; retained after account/package deletion.';
comment on column public.coach_purchases.currency_snapshot is
  'Currency at purchase time; retained after account/package deletion.';

commit;
