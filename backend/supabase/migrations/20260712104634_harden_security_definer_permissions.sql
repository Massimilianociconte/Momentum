begin;

revoke all
on function public.send_friend_request(uuid, text)
from public, anon, authenticated;

grant execute
on function public.send_friend_request(uuid, text)
to authenticated;

commit;
