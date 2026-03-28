create table if not exists public.reportkit_push_deliveries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.reportkit_live_activity_events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  token_table text not null check (token_table in ('live_activity', 'device')),
  token_row_id uuid not null,
  apns_status int not null,
  apns_id text null,
  error_code text null,
  response_excerpt text null,
  created_at timestamptz not null default now()
);

create index if not exists reportkit_push_deliveries_event_idx
  on public.reportkit_push_deliveries (event_id);

create index if not exists reportkit_push_deliveries_user_created_idx
  on public.reportkit_push_deliveries (user_id, created_at desc);

alter table public.reportkit_push_deliveries enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reportkit_push_deliveries'
      and policyname = 'reportkit_push_deliveries_select_own'
  ) then
    create policy reportkit_push_deliveries_select_own
      on public.reportkit_push_deliveries
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;
end $$;
