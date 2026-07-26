-- Optimize RLS: wrap per-row auth.uid() in (select auth.uid()) so Postgres
-- evaluates it once per statement (InitPlan) instead of once per row. auth.uid()
-- is STABLE, so semantics are unchanged. Resolves auth_rls_initplan advisories.
-- Ref: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select
--
-- Intentionally EXCLUDED (self-referential tables whose policies read their own
-- table; wrapping there triggers 42P17 infinite recursion — left as-is):
--   profiles: own profile insert / own profile read / own profile write
--   friend_group_members: group members member read

ALTER POLICY "admin test account read own" ON public.admin_test_accounts
  USING ((( SELECT auth.uid() ) = user_id));

ALTER POLICY "assistant read own" ON public.assistant_queries
  USING ((( SELECT auth.uid() ) = user_id));

ALTER POLICY "assistant reports read own" ON public.assistant_reports
  USING ((( SELECT auth.uid() ) = user_id));

ALTER POLICY "assignments coach delete" ON public.coach_assignments
  USING ((( SELECT auth.uid() ) = coach_id));

ALTER POLICY "assignments coach insert" ON public.coach_assignments
  WITH CHECK (((( SELECT auth.uid() ) = coach_id) AND ((purchase_id IS NOT NULL) OR (EXISTS ( SELECT 1
   FROM coach_athletes ca
  WHERE ((ca.coach_id = coach_assignments.coach_id) AND (ca.athlete_id = coach_assignments.player_id) AND (ca.status = 'ACTIVE'::text)))))));

ALTER POLICY "assignments coach read" ON public.coach_assignments
  USING ((( SELECT auth.uid() ) = coach_id));

ALTER POLICY "assignments coach update" ON public.coach_assignments
  USING ((( SELECT auth.uid() ) = coach_id))
  WITH CHECK ((( SELECT auth.uid() ) = coach_id));

ALTER POLICY "assignments player progress" ON public.coach_assignments
  USING ((( SELECT auth.uid() ) = player_id))
  WITH CHECK ((( SELECT auth.uid() ) = player_id));

ALTER POLICY "assignments player read" ON public.coach_assignments
  USING ((( SELECT auth.uid() ) = player_id));

ALTER POLICY "coach athletes participants read" ON public.coach_athletes
  USING (((( SELECT auth.uid() ) = coach_id) OR (( SELECT auth.uid() ) = athlete_id)));

ALTER POLICY "packages coach write" ON public.coach_packages
  USING ((( SELECT auth.uid() ) = coach_id))
  WITH CHECK ((( SELECT auth.uid() ) = coach_id));

ALTER POLICY "packages public read" ON public.coach_packages
  USING (((status = 'ACTIVE'::text) OR (( SELECT auth.uid() ) = coach_id)));

ALTER POLICY "coach own update" ON public.coach_profiles
  USING ((( SELECT auth.uid() ) = coach_id))
  WITH CHECK ((( SELECT auth.uid() ) = coach_id));

ALTER POLICY "coach own write" ON public.coach_profiles
  WITH CHECK (((( SELECT auth.uid() ) = coach_id) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.user_id = ( SELECT auth.uid() )) AND (p.plan = 'coach'::text))))));

ALTER POLICY "coach public read" ON public.coach_profiles
  USING (((visible = true) OR (( SELECT auth.uid() ) = coach_id)));

ALTER POLICY "purchases read own" ON public.coach_purchases
  USING (((( SELECT auth.uid() ) = player_id) OR (( SELECT auth.uid() ) = coach_id)));

ALTER POLICY "duo events insert own team" ON public.duo_events
  WITH CHECK (((( SELECT auth.uid() ) = source_user_id) AND (source_team_id = duo_team_of(session_id, ( SELECT auth.uid() ))) AND (EXISTS ( SELECT 1
   FROM duo_sessions s
  WHERE ((s.session_id = duo_events.session_id) AND (s.match_id = duo_events.match_id) AND ((( SELECT auth.uid() ) = s.creator_id) OR (( SELECT auth.uid() ) = s.guest_id)) AND (s.status = ANY (ARRAY['PENDING'::text, 'ACTIVE'::text]))))) AND (((type = 'POINT_TEAM_A'::text) AND (team_id = 'TEAM_A'::text) AND (duo_team_of(session_id, ( SELECT auth.uid() )) = 'TEAM_A'::text)) OR ((type = 'POINT_TEAM_B'::text) AND (team_id = 'TEAM_B'::text) AND (duo_team_of(session_id, ( SELECT auth.uid() )) = 'TEAM_B'::text)) OR ((type = 'UNDO'::text) AND (team_id = duo_team_of(session_id, ( SELECT auth.uid() )))) OR (type = ANY (ARRAY['MATCH_STARTED'::text, 'MATCH_PAUSED'::text, 'MATCH_RESUMED'::text, 'MATCH_COMPLETED'::text, 'DEVICE_JOINED_MATCH'::text, 'DEVICE_LEFT_MATCH'::text, 'TEAM_CONFIRMED'::text])))));

ALTER POLICY "duo events participants read" ON public.duo_events
  USING ((EXISTS ( SELECT 1
   FROM duo_sessions s
  WHERE ((s.session_id = duo_events.session_id) AND ((( SELECT auth.uid() ) = s.creator_id) OR (( SELECT auth.uid() ) = s.guest_id))))));

ALTER POLICY "duo session create" ON public.duo_sessions
  WITH CHECK (((( SELECT auth.uid() ) = creator_id) AND has_duo_access(( SELECT auth.uid() ))));

ALTER POLICY "duo session participants read" ON public.duo_sessions
  USING (((( SELECT auth.uid() ) = creator_id) OR (( SELECT auth.uid() ) = guest_id)));

ALTER POLICY "duo session participants update" ON public.duo_sessions
  USING (((( SELECT auth.uid() ) = creator_id) OR (( SELECT auth.uid() ) = guest_id)))
  WITH CHECK (((( SELECT auth.uid() ) = creator_id) OR (( SELECT auth.uid() ) = guest_id)));

ALTER POLICY "groups member read" ON public.friend_groups
  USING ((EXISTS ( SELECT 1
   FROM friend_group_members m
  WHERE ((m.group_id = friend_groups.group_id) AND (m.user_id = ( SELECT auth.uid() ))))));

ALTER POLICY "invite audit actor read" ON public.invite_audit
  USING ((actor_id = ( SELECT auth.uid() )));

ALTER POLICY "invite owner read" ON public.invite_tokens
  USING ((inviter_id = ( SELECT auth.uid() )));

ALTER POLICY "proposal participants read" ON public.match_proposals
  USING (((( SELECT auth.uid() ) = creator_id) OR (( SELECT auth.uid() ) = receiver_id)));

ALTER POLICY "contact request participants read" ON public.social_contact_requests
  USING (((( SELECT auth.uid() ) = requester_id) OR (( SELECT auth.uid() ) = receiver_id)));

ALTER POLICY "reporter read own reports" ON public.social_reports
  USING ((reporter_id = ( SELECT auth.uid() )));

ALTER POLICY "team connections participant read" ON public.team_connections
  USING ((EXISTS ( SELECT 1
   FROM teams t
  WHERE ((t.team_id = ANY (ARRAY[team_connections.team_low, team_connections.team_high])) AND (t.owner_id = ( SELECT auth.uid() ))))));

ALTER POLICY "team join participants read" ON public.team_join_requests
  USING (((( SELECT auth.uid() ) = team_owner_id) OR (( SELECT auth.uid() ) = requester_id)));

ALTER POLICY "membership participants read" ON public.team_memberships
  USING (((user_id = ( SELECT auth.uid() )) OR (EXISTS ( SELECT 1
   FROM teams t
  WHERE ((t.team_id = team_memberships.team_id) AND (t.owner_id = ( SELECT auth.uid() )))))));

ALTER POLICY "team owner delete" ON public.teams
  USING ((owner_id = ( SELECT auth.uid() )));

ALTER POLICY "team owner insert" ON public.teams
  WITH CHECK ((owner_id = ( SELECT auth.uid() )));

ALTER POLICY "team owner update" ON public.teams
  USING ((owner_id = ( SELECT auth.uid() )))
  WITH CHECK ((owner_id = ( SELECT auth.uid() )));

ALTER POLICY "team participant or public read" ON public.teams
  USING (((visibility = 'PUBLIC'::text) OR (owner_id = ( SELECT auth.uid() )) OR (EXISTS ( SELECT 1
   FROM team_memberships m
  WHERE ((m.team_id = teams.team_id) AND (m.user_id = ( SELECT auth.uid() )) AND (m.status = 'ACCEPTED'::text))))));

ALTER POLICY "blocks owner read" ON public.user_blocks
  USING ((( SELECT auth.uid() ) = blocker_id));

ALTER POLICY "own cards" ON public.wrapped_cards
  USING ((( SELECT auth.uid() ) = user_id))
  WITH CHECK ((( SELECT auth.uid() ) = user_id));

