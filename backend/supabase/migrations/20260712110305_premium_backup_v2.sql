-- RallyMate Premium backup v2.
--
-- The client stores a versioned, hierarchical snapshot of app-owned data.
-- HealthKit / Health Connect data, auth tokens, billing state and device
-- diagnostics are intentionally excluded. Team media remains in the private
-- team-avatars bucket and is referenced only by its owner-scoped object path.

alter table public.backups
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists payload_sha256 text,
  add column if not exists payload_bytes bigint not null default 0;

create or replace function public.set_backup_metadata()
returns trigger
language plpgsql
set search_path = public, extensions, pg_catalog
as $$
begin
  new.payload_bytes := octet_length(convert_to(new.payload::text, 'UTF8'));
  if new.payload_bytes > 20971520 then
    raise exception using
      errcode = '23514',
      message = 'backup_payload_too_large';
  end if;

  if new.schema_ver >= 2 and (
    new.payload->>'format' is distinct from 'rallymate-backup'
    or coalesce((new.payload->>'v')::int, 0) is distinct from new.schema_ver
  ) then
    raise exception using
      errcode = '23514',
      message = 'backup_payload_format_invalid';
  end if;

  new.payload_sha256 := encode(
    extensions.digest(convert_to(new.payload::text, 'UTF8'), 'sha256'),
    'hex'
  );
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists backups_set_metadata on public.backups;
create trigger backups_set_metadata
before insert or update of payload, schema_ver on public.backups
for each row execute function public.set_backup_metadata();

-- Backfill metadata for v1 rows created before this migration.
update public.backups
set payload_bytes = octet_length(convert_to(payload::text, 'UTF8')),
    payload_sha256 = encode(
      extensions.digest(convert_to(payload::text, 'UTF8'), 'sha256'),
      'hex'
    );

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'backups_device_id_valid'
      and conrelid = 'public.backups'::regclass
  ) then
    alter table public.backups add constraint backups_device_id_valid
      check (
        char_length(device_id) between 1 and 64
        and device_id ~ '^[A-Za-z0-9_-]+$'
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'backups_schema_ver_valid'
      and conrelid = 'public.backups'::regclass
  ) then
    alter table public.backups add constraint backups_schema_ver_valid
      check (schema_ver between 1 and 1000);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'backups_payload_bytes_valid'
      and conrelid = 'public.backups'::regclass
  ) then
    alter table public.backups add constraint backups_payload_bytes_valid
      check (payload_bytes between 2 and 20971520);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'backups_payload_sha256_valid'
      and conrelid = 'public.backups'::regclass
  ) then
    alter table public.backups add constraint backups_payload_sha256_valid
      check (payload_sha256 ~ '^[0-9a-f]{64}$');
  end if;
end;
$$;

-- Reading/restoring and writing backups are Premium operations. Direct table
-- deletion remains available while Premium; downgraded users use the guarded
-- delete_my_backup RPC below without gaining read access.
drop policy if exists "own backup" on public.backups;
drop policy if exists "premium backup select" on public.backups;
drop policy if exists "premium backup insert" on public.backups;
drop policy if exists "premium backup update" on public.backups;
drop policy if exists "own backup delete" on public.backups;

create policy "premium backup select" on public.backups
  for select to authenticated
  using (auth.uid() = user_id and public.has_cloud_media_access());

create policy "premium backup insert" on public.backups
  for insert to authenticated
  with check (auth.uid() = user_id and public.has_cloud_media_access());

create policy "premium backup update" on public.backups
  for update to authenticated
  using (auth.uid() = user_id and public.has_cloud_media_access())
  with check (auth.uid() = user_id and public.has_cloud_media_access());

create policy "own backup delete" on public.backups
  for delete to authenticated
  using (auth.uid() = user_id);

create or replace function public.delete_my_backup(
  p_device_id text default null
)
returns integer
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_deleted integer;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if p_device_id is not null and p_device_id !~ '^[A-Za-z0-9_-]{1,64}$' then
    raise exception using errcode = '22023', message = 'invalid_device_id';
  end if;

  delete from public.backups b
  where b.user_id = v_user_id
    and (p_device_id is null or b.device_id = p_device_id);
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.set_backup_metadata() from public, anon, authenticated;
revoke all on function public.delete_my_backup(text) from public, anon;
grant execute on function public.delete_my_backup(text) to authenticated;

comment on table public.backups is
  'Premium-only versioned RallyMate snapshots. Health data and credentials are excluded.';
comment on column public.backups.payload_sha256 is
  'Server-computed integrity fingerprint of the canonical jsonb representation.';
comment on column public.backups.payload_bytes is
  'Server-computed UTF-8 payload size, limited to 20 MiB.';
