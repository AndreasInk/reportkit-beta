create table if not exists public.reportkit_live_activity_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workspace_id uuid null,
  event text not null check (event in ('start', 'update', 'end')),
  apns_env text not null check (apns_env in ('sandbox', 'production')),
  device_install_id text null,
  payload_hash text not null,
  idempotency_key text not null,
  target_count int not null default 0,
  success_count int not null default 0,
  failure_count int not null default 0,
  status text not null default 'queued' check (status in ('queued', 'sent', 'partial', 'failed', 'no_targets')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists reportkit_live_activity_events_user_idempotency_unique
  on public.reportkit_live_activity_events (user_id, idempotency_key);

create index if not exists reportkit_live_activity_events_user_created_idx
  on public.reportkit_live_activity_events (user_id, created_at desc);

alter table public.reportkit_live_activity_events enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reportkit_live_activity_events'
      and policyname = 'reportkit_live_activity_events_select_own'
  ) then
    create policy reportkit_live_activity_events_select_own
      on public.reportkit_live_activity_events
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;
end $$;
