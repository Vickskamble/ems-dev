-- Migration: trial-expiry email notifications (server-side)
--
-- Adds:
--   1. trial_notify_log          — dedupe log (one 'upcoming' + one 'expired' per user)
--   2. get_trial_expiry_recipients() — service-role RPC used by the
--      trial-expiry-notify edge function (daily cron)
--
-- Rules mirrored from get_entitlement():
--   trial_end = profiles.trial_started_at + 30 days
--   active sub (status in 'active'|'authenticated') -> never notified
--   user without a profile row / trial_started_at -> never notified (app never locks them)
--   demo@powerems.com -> never notified

create table if not exists public.trial_notify_log (
  user_id     uuid not null references auth.users(id) on delete cascade,
  notify_type text not null check (notify_type in ('upcoming', 'expired')),
  trial_end   timestamptz not null,
  sent_at     timestamptz not null default now(),
  primary key (user_id, notify_type)
);

comment on table public.trial_notify_log is
  'Dedupe log for trial-expiry emails. Edge function inserts a row only after a successful send.';

alter table public.trial_notify_log enable row level security;

-- No select/insert policies: only the edge function (service role) writes.

create or replace function public.get_trial_expiry_recipients()
returns table (
  user_id     uuid,
  email       text,
  trial_end   timestamptz,
  notify_type text,
  days_left   int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
begin
  return query
  select
    au.id,
    au.email::text,
    p.trial_started_at + interval '30 days' as trial_end,
    case
      when v_now >= p.trial_started_at + interval '30 days' then 'expired'
      else 'upcoming'
    end as notify_type,
    case
      when v_now >= p.trial_started_at + interval '30 days' then 0
      else greatest(
        1,
        ceil(extract(epoch from ((p.trial_started_at + interval '30 days') - v_now)) / 86400.0)::int
      )
    end as days_left
  from auth.users au
  join public.profiles p on p.user_id = au.id
  left join public.subscriptions s on s.user_id = au.id
  where au.email is distinct from 'demo@powerems.com'
    and p.trial_started_at is not null
    and coalesce(s.status, 'none') not in ('active', 'authenticated')
    and (
      v_now >= p.trial_started_at + interval '30 days'
      or (p.trial_started_at + interval '30 days' - v_now) <= interval '3 days'
    )
    and not exists (
      select 1
      from public.trial_notify_log l
      where l.user_id = au.id
        and l.notify_type = case
          when v_now >= p.trial_started_at + interval '30 days' then 'expired'
          else 'upcoming'
        end
    )
  order by trial_end;
end;
$$;

revoke all on function public.get_trial_expiry_recipients() from public;
grant execute on function public.get_trial_expiry_recipients() to service_role;