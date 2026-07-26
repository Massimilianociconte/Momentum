begin;

create extension if not exists pgtap with schema extensions;
select plan(3);

select is(
  (
    select count(*)::int
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and has_function_privilege('anon', p.oid, 'EXECUTE')
  ),
  0,
  'anonymous clients cannot execute public SECURITY DEFINER functions'
);

select is(
  (
    select count(*)::int
    from unnest(array[
      'public.claim_wearable_pairing(text,text,text,text,text[],timestamptz)',
      'public.consume_wearable_oauth_state(text)',
      'public.grant_super_admin_by_email(text,text)',
      'public.increment_card_views(uuid)',
      'public.invite_hash(text)',
      'public.set_plan(uuid,text,timestamptz)'
    ]) as internal(signature)
    where has_function_privilege(
      'authenticated',
      to_regprocedure(internal.signature),
      'EXECUTE'
    )
  ),
  0,
  'authenticated clients cannot execute service-only privileged functions'
);

select is(
  (
    select count(*)::int
    from unnest(array[
      'public.discover_social_players(int)',
      'public.social_player_profile(uuid)',
      'public.send_friend_request(uuid,text)',
      'public.respond_friend_request(uuid,boolean)',
      'public.cancel_friend_request(uuid)',
      'public.remove_friend(uuid)',
      'public.block_user(uuid)',
      'public.unblock_user(uuid)',
      'public.social_relationships()',
      'public.social_inbox()',
      'public.blocked_users()',
      'public.report_social_user(uuid,text,text)',
      'public.send_match_proposal(uuid,text,text)',
      'public.send_team_join_request(uuid,text)',
      'public.respond_social_item(text,uuid,boolean)',
      'public.has_cloud_media_access()',
      'public.upsert_cloud_team(text,text,text,bigint,text)',
      'public.set_team_avatar(uuid,text)',
      'public.my_cloud_teams()',
      'public.create_invite(text,uuid,uuid,text,uuid,int,uuid)',
      'public.preview_invite(text)',
      'public.redeem_invite(text)',
      'public.revoke_invite(uuid)',
      'public.has_duo_access(uuid)',
      'public.duo_team_of(uuid,uuid)',
      'public.duo_create_session(text,jsonb,text)',
      'public.duo_join_session(text)',
      'public.duo_ack_state(uuid,bigint,boolean)',
      'public.duo_set_session_status(uuid,text)',
      'public.my_wearable_connections()',
      'public.delete_my_backup(text)'
    ]) as client_rpc(signature)
    where not has_function_privilege(
      'authenticated',
      to_regprocedure(client_rpc.signature),
      'EXECUTE'
    )
  ),
  0,
  'authenticated clients retain every allowlisted RPC'
);

select * from finish();
rollback;
