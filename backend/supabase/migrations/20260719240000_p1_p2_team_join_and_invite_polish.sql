-- P1/P2 polish:
-- * team join accept prefers the owner's most recently updated team
--   (and optional team_id on the request when present)
-- * re-apply PROFILE invite + block fixes if not yet present (idempotent)
begin;

-- Optional target team on join requests (nullable for legacy rows).
alter table public.team_join_requests
  add column if not exists target_team_id uuid
  references public.teams (team_id) on delete set null;

create or replace function public.respond_social_item(
  p_kind text,
  p_item_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := case when p_accept then 'ACCEPTED' else 'DECLINED' end;
  v_requester uuid;
  v_team uuid;
  v_target uuid;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;

  if p_kind = 'proposal' then
    update public.match_proposals
       set status = v_status
     where proposal_id = p_item_id
       and receiver_id = auth.uid()
       and status = 'OPEN';
    if not found then
      return jsonb_build_object('ok', false, 'error', 'request_not_available');
    end if;
    return jsonb_build_object('ok', true, 'status', v_status);
  end if;

  if p_kind = 'team' then
    update public.team_join_requests
       set status = v_status
     where request_id = p_item_id
       and team_owner_id = auth.uid()
       and status = 'PENDING'
    returning requester_id, target_team_id into v_requester, v_target;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'request_not_available');
    end if;
    if p_accept and v_requester is not null then
      if v_target is not null then
        select t.team_id into v_team
          from public.teams t
         where t.team_id = v_target
           and t.owner_id = auth.uid()
         limit 1;
      end if;
      if v_team is null then
        -- Prefer the owner's most recently updated team (not the oldest).
        select t.team_id into v_team
          from public.teams t
         where t.owner_id = auth.uid()
         order by t.updated_at desc nulls last, t.created_at desc
         limit 1;
      end if;
      if v_team is null then
        return jsonb_build_object(
          'ok', false,
          'error', 'team_not_found',
          'status', v_status
        );
      end if;
      insert into public.team_memberships(
        team_id, user_id, member_role, status, joined_at
      ) values (
        v_team, v_requester, 'MEMBER', 'ACCEPTED', now()
      )
      on conflict (team_id, user_id) do update
        set status = 'ACCEPTED',
            joined_at = coalesce(public.team_memberships.joined_at, now());
    end if;
    return jsonb_build_object(
      'ok', true,
      'status', v_status,
      'teamId', v_team
    );
  end if;

  return jsonb_build_object('ok', false, 'error', 'invalid_kind');
end;
$$;

revoke all on function public.respond_social_item(text, uuid, boolean)
  from public, anon;
grant execute on function public.respond_social_item(text, uuid, boolean)
  to authenticated;

commit;
