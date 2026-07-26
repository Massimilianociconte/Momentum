-- These objects are created after the general privilege-hardening migrations,
-- so remove PostgreSQL/Supabase default grants explicitly. Access remains via
-- the allowlisted authenticated RPCs defined by their owning migration.
revoke all on table
  public.friend_groups,
  public.friend_group_members,
  public.coach_athletes
from public, anon, authenticated;

revoke all on function public._guard_assignment_player_update()
from public, anon, authenticated;
