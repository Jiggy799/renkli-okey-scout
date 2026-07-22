-- ─────────────────────────────────────────────────────────────────────────────
-- OkeyScout — Supabase PostgreSQL Schema
-- ─────────────────────────────────────────────────────────────────────────────
--
-- ⚠️  IMPORTANT: Run this in your Supabase SQL Editor before starting the app.
--    Go to: https://app.supabase.com → Your Project → SQL Editor → Paste & Run
--
-- What this sets up:
--   • Row-Level Security (RLS) so players can only read/write their own data
--   • Realtime subscriptions on: tables, table_players, rounds
--   • Helper functions for table/lobby management
-- ─────────────────────────────────────────────────────────────────────────────

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ─────────────────────────────────────────────────────────────────────────────
-- PROFILES
-- Player accounts (extends auth.users)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  username     text not null unique,
  avatar_url   text,
  created_at   timestamptz default now() not null
);

alter table public.profiles enable row level security;

create policy "Players can view all profiles"
  on public.profiles for select using (true);

create policy "Players can insert their own profile"
  on public.profiles for insert with check (auth.uid() = id);

create policy "Players can update their own profile"
  on public.profiles for update using (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'Spieler_' || substr(new.id::text, 1, 4)),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLES  (a game table / room)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.tables (
  id            text primary key,                    -- 4-digit numeric code, e.g. '4821'
  status        text not null default 'lobby',       -- 'lobby' | 'playing' | 'finished'
  current_round int  not null default 0,
  gösterge_tile jsonb,                               -- { color, number } set by table creator
  created_by    uuid references public.profiles(id),
  created_at    timestamptz default now() not null,
  check (status in ('lobby', 'playing', 'finished'))
);

alter table public.tables enable row level security;

-- Anyone can read tables (needed to join via code)
create policy "Anyone can view tables"
  on public.tables for select using (true);

-- Only authenticated players can create tables
create policy "Authenticated players can create tables"
  on public.tables for insert with check (auth.role() = 'authenticated');

-- Creator can update their table during lobby
create policy "Creator can update their table"
  on public.tables for update using (auth.uid() = created_by);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE_PLAYERS  (who is seated at which table)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.table_players (
  id          uuid default uuid_generate_v4() primary key,
  table_id    text  not null references public.tables(id) on delete cascade,
  player_id   uuid  not null references public.profiles(id) on delete cascade,
  seat_index  int   not null check (seat_index between 0 and 3),  -- 0-3 = 4 seats
  is_ready    boolean not null default false,
  is_creator  boolean not null default false,
  joined_at   timestamptz default now() not null,
  unique (table_id, player_id),
  unique (table_id, seat_index)
);

alter table public.table_players enable row level security;

create policy "Anyone can view players in a table"
  on public.table_players for select using (true);

create policy "Authenticated players can join tables"
  on public.table_players for insert with check (auth.role() = 'authenticated');

create policy "Players can update their own ready status"
  on public.table_players for update using (auth.uid() = player_id);

create policy "Players can leave a table"
  on public.table_players for delete using (auth.uid() = player_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- ROUNDS  (one round per gösterge reveal)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.rounds (
  id                    uuid default uuid_generate_v4() primary key,
  table_id              text  not null references public.tables(id) on delete cascade,
  round_number          int   not null,
  gösterge_tile         jsonb not null,   -- { color: 'RED', number: 8 }
  gösterge_player_id    uuid references public.profiles(id),  -- who selected gösterge
  gösterge_confirmed_by uuid references public.profiles(id),  -- who confirmed gösterge
  gösterge_confirmed    boolean not null default false,
  status                text not null default 'gösterge_selection',  -- 'gösterge_selection' | 'playing' | 'finished'
  winner_id             uuid references public.profiles(id),
  started_at            timestamptz,
  finished_at           timestamptz,
  created_at            timestamptz default now() not null,
  check (status in ('gösterge_selection', 'playing', 'finished')),
  check (gösterge_confirmed = true or gösterge_confirmed_by is null)
);

alter table public.rounds enable row level security;

create policy "Table players can view rounds"
  on public.rounds for select using (
    exists (
      select 1 from public.table_players
      where table_players.table_id = rounds.table_id
        and table_players.player_id = auth.uid()
    )
  );

create policy "Players at table can insert rounds"
  on public.rounds for insert with check (
    exists (
      select 1 from public.table_players
      where table_players.table_id = rounds.table_id
        and table_players.player_id = auth.uid()
    )
  );

create policy "Players at table can update rounds"
  on public.rounds for update using (
    exists (
      select 1 from public.table_players
      where table_players.table_id = rounds.table_id
        and table_players.player_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- REALTIME
-- Enable realtime subscriptions for the app (must be done as supabase admin)
-- ─────────────────────────────────────────────────────────────────────────────
alter publication supabase_realtime add table public.tables;
alter publication supabase_realtime add table public.table_players;
alter publication supabase_realtime add table public.rounds;

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPER FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- Get the gösterge tile for the current round of a table
create or replace function public.get_current_gösterge(p_table_id text)
returns jsonb language sql security definer as $$
  select gösterge_tile
  from public.rounds
  where table_id = p_table_id
    and status = 'playing'
  order by round_number desc
  limit 1;
$$;

-- Get all players at a table with their seat info
create or replace function public.get_table_players(p_table_id text)
returns table (
  player_id   uuid,
  username    text,
  avatar_url  text,
  seat_index  int,
  is_ready    boolean,
  is_creator  boolean
) language sql security definer as $$
  select
    tp.player_id,
    p.username,
    p.avatar_url,
    tp.seat_index,
    tp.is_ready,
    tp.is_creator
  from public.table_players tp
  join public.profiles p on p.id = tp.player_id
  where tp.table_id = p_table_id
  order by tp.seat_index;
$$;

-- Check if all 4 players at a table are ready
create or replace function public.all_players_ready(p_table_id text)
returns boolean language sql security definer as $$
  select (
    select count(*) = 4
    from public.table_players
    where table_id = p_table_id and is_ready = true
  )
  and (
    select count(*) = 4
    from public.table_players
    where table_id = p_table_id
  );
$$;
