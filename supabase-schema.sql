-- Supabase schema for Xadrez Arena
-- Execute this script in Supabase SQL Editor.

-- Se existir uma tabela legada com users.id diferente de uuid,
-- faz backup e recria a tabela no formato correto para o Supabase Auth.
do $$
declare
  id_udt text;
begin
  if to_regclass('public.users') is null then
    return;
  end if;

  select c.udt_name
  into id_udt
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'users'
    and c.column_name = 'id';

  if id_udt is not null and id_udt <> 'uuid' then
    if to_regclass('public.users_legacy_backup') is null then
      execute 'alter table public.users rename to users_legacy_backup';
    else
      execute 'drop table public.users cascade';
    end if;
  end if;
end
$$;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  auth_email text not null unique,
  emoji text not null default '♟',
  elo integer not null default 800,
  wins integer not null default 0,
  losses integer not null default 0,
  draws integer not null default 0,
  total_games integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_username_len check (char_length(username) between 3 and 20),
  constraint users_elo_min check (elo >= 100),
  constraint users_stats_non_negative check (
    wins >= 0 and losses >= 0 and draws >= 0 and total_games >= 0
  )
);

-- Compatibilidade para bases que ja tinham public.users sem a coluna username
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users' and column_name = 'username'
  ) then
    alter table public.users add column username text;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users' and column_name = 'auth_email'
  ) then
    alter table public.users add column auth_email text;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users' and column_name = 'emoji'
  ) then
    alter table public.users add column emoji text default '♟';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users' and column_name = 'elo'
  ) then
    alter table public.users add column elo integer default 800;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users' and column_name = 'wins'
  ) then
    alter table public.users add column wins integer default 0;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users' and column_name = 'losses'
  ) then
    alter table public.users add column losses integer default 0;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users' and column_name = 'draws'
  ) then
    alter table public.users add column draws integer default 0;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users' and column_name = 'total_games'
  ) then
    alter table public.users add column total_games integer default 0;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users' and column_name = 'created_at'
  ) then
    alter table public.users add column created_at timestamptz default now();
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users' and column_name = 'updated_at'
  ) then
    alter table public.users add column updated_at timestamptz default now();
  end if;
end
$$;

do $$
begin
  -- Migra coluna legada "user" -> username quando existir
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'user'
  ) then
    execute format(
      'update public.users set username = coalesce(username, nullif(btrim(%I), %L)) where username is null or btrim(username) = %L',
      'user', '', ''
    );
  end if;
end
$$;

-- Garante username preenchido
update public.users
set username = coalesce(
  nullif(btrim(username), ''),
  nullif(split_part(coalesce(auth_email, ''), '@', 1), ''),
  'jogador_' || substr(id::text, 1, 8)
)
where username is null or btrim(username) = '';

-- Garante unicidade de usernames legados antes do indice unico
with ranked as (
  select
    id,
    row_number() over (partition by lower(username) order by created_at nulls last, id) as rn
  from public.users
)
update public.users u
set username = left(coalesce(nullif(btrim(u.username), ''), 'jogador'), 15) || '_' || substr(u.id::text, 1, 4)
from ranked r
where u.id = r.id
  and r.rn > 1;

alter table public.users alter column username set not null;

create unique index if not exists users_username_unique_ci
  on public.users (lower(username));

create or replace function public.set_users_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at
before update on public.users
for each row
execute function public.set_users_updated_at();

alter table public.users enable row level security;

-- Public ranking read
drop policy if exists users_select_public on public.users;
create policy users_select_public
on public.users
for select
using (true);

-- User can create only their own profile (id must be auth.uid())
drop policy if exists users_insert_self on public.users;
create policy users_insert_self
on public.users
for insert
with check (auth.uid() = id);

-- User can update only their own profile
drop policy if exists users_update_self on public.users;
create policy users_update_self
on public.users
for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- User can delete only their own profile
drop policy if exists users_delete_self on public.users;
create policy users_delete_self
on public.users
for delete
using (auth.uid() = id);

-- Optional: full account deletion (profile + auth user)
-- The frontend tries this function first and falls back to profile deletion if unavailable.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  delete from public.users where id = uid;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
