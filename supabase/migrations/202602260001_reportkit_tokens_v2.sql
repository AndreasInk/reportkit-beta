create extension if not exists pgcrypto;

create table if not exists public.reportkit_live_activity_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_install_id text not null,
  apns_env text not null check (apns_env in ('sandbox', 'production')),
  token_hex text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reportkit_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_install_id text not null,
  apns_env text not null check (apns_env in ('sandbox', 'production')),
  token_hex text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.reportkit_live_activity_tokens
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists is_active boolean not null default true,
  add column if not exists last_seen_at timestamptz not null default now();

alter table if exists public.reportkit_device_tokens
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists is_active boolean not null default true,
  add column if not exists last_seen_at timestamptz not null default now();

-- Hard cutover: old rows had no user ownership; remove them.
delete from public.reportkit_live_activity_tokens where user_id is null;
delete from public.reportkit_device_tokens where user_id is null;

alter table public.reportkit_live_activity_tokens
  alter column user_id set not null;

alter table public.reportkit_device_tokens
  alter column user_id set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reportkit_live_activity_tokens_token_hex_check'
  ) then
    alter table public.reportkit_live_activity_tokens
      add constraint reportkit_live_activity_tokens_token_hex_check
      check (
        token_hex ~ '^[0-9A-Fa-f]+$'
        and char_length(token_hex) between 64 and 1024
        and mod(char_length(token_hex), 2) = 0
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'reportkit_device_tokens_token_hex_check'
  ) then
    alter table public.reportkit_device_tokens
      add constraint reportkit_device_tokens_token_hex_check
      check (
        token_hex ~ '^[0-9A-Fa-f]+$'
        and char_length(token_hex) between 64 and 1024
        and mod(char_length(token_hex), 2) = 0
      );
  end if;
end $$;

drop index if exists public.reportkit_tokens_unique;
drop index if exists public.reportkit_live_activity_tokens_unique;
drop index if exists public.reportkit_device_tokens_unique;

create unique index if not exists reportkit_live_activity_tokens_user_install_env_unique
  on public.reportkit_live_activity_tokens (user_id, device_install_id, apns_env);

create unique index if not exists reportkit_device_tokens_user_install_env_unique
  on public.reportkit_device_tokens (user_id, device_install_id, apns_env);

create index if not exists reportkit_live_activity_tokens_lookup_idx
  on public.reportkit_live_activity_tokens (user_id, apns_env, is_active, updated_at desc);

create index if not exists reportkit_device_tokens_lookup_idx
  on public.reportkit_device_tokens (user_id, apns_env, is_active, updated_at desc);

alter table public.reportkit_live_activity_tokens enable row level security;
alter table public.reportkit_device_tokens enable row level security;
