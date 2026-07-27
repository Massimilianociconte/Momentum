-- Star Point uses scoring schema v2. Duo's legacy RPCs do not yet negotiate
-- the scoring protocol of both phones, so accepting it would let an older peer
-- interpret goldenPoint=false as ADVANTAGE. Keep Duo fail-closed until a
-- versioned create/join handshake is deployed.
create or replace function public.reject_unnegotiated_star_point_duo()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if upper(coalesce(new.format_json ->> 'gameScoringMode', '')) = 'STAR_POINT'
  then
    raise exception using
      errcode = 'P0001',
      message = 'client_update_required';
  end if;
  return new;
end;
$$;

revoke all on function public.reject_unnegotiated_star_point_duo() from public;
revoke all on function public.reject_unnegotiated_star_point_duo() from anon;
revoke all on function public.reject_unnegotiated_star_point_duo()
  from authenticated;

drop trigger if exists reject_unnegotiated_star_point_duo
  on public.duo_sessions;
create trigger reject_unnegotiated_star_point_duo
before insert or update of format_json on public.duo_sessions
for each row execute function public.reject_unnegotiated_star_point_duo();
