-- ─────────────────────────────────────────────────────────────────────────────
-- RenkliOkeyScout — Supabase PostgreSQL Schema (Updated)
-- Run this in: https://app.supabase.com → SQL Editor
-- ─────────────────────────────────────────────────────────────────────────────

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ─── PROFILES ───────────────────────────────────────────────────────────────
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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─── TABLES ─────────────────────────────────────────────────────────────────
create table if not exists public.tables (
  id             text primary key,                    -- 4-digit code, e.g. '4821'
  status         text not null default 'lobby',      -- 'lobby' | 'playing' | 'finished'
  current_round  int  not null default 0,
  gösterge_tile  jsonb,                               -- { "color": "red", "number": 8 }
  created_by     uuid references public.profiles(id),
  created_at     timestamptz default now() not null,
  constraint tables_status check (status in ('lobby', 'playing', 'finished'))
);

alter table public.tables enable row level security;

create policy "Anyone can view tables"
  on public.tables for select using (true);

create policy "Authenticated players can create tables"
  on public.tables for insert with check (auth.role() = 'authenticated');

create policy "Creator can update their table"
  on public.tables for update using (auth.uid() = created_by);

-- ─── TABLE_PLAYERS ──────────────────────────────────────────────────────────
create table if not exists public.table_players (
  id                   uuid default uuid_generate_v4() primary key,
  table_id             text  not null references public.tables(id) on delete cascade,
  player_id            uuid  not null references public.profiles(id) on delete cascade,
  seat_index           int   not null check (seat_index between 0 and 3),
  is_ready             boolean not null default false,
  is_creator           boolean not null default false,
  is_cifte             boolean not null default false,   -- çifte gitmek active this round
  cumulative_penalty   int    not null default 0,         -- total penalty points
  joined_at            timestamptz default now() not null,
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

create policy "Players can update their own cifte"
  on public.table_players for update using (auth.uid() = player_id);

create policy "Players can leave a table"
  on public.table_players for delete using (auth.uid() = player_id);

-- ─── ROUNDS ─────────────────────────────────────────────────────────────────
create table if not exists public.rounds (
  id                   uuid default uuid_generate_v4() primary key,
  table_id             text  not null references public.tables(id) on delete cascade,
  round_number         int   not null,
  gösterge_tile        jsonb not null,
  gösterge_player_id   uuid references public.profiles(id),
  winner_id            uuid references public.profiles(id),
  win_type             text not null default 'normal',
                        -- 'normal' | 'okey' | 'cifte' | 'okeyCifte'
  status               text not null default 'gösterge_selection',
                        -- 'gösterge_selection' | 'playing' | 'finished'
  started_at           timestamptz,
  finished_at          timestamptz,
  created_at           timestamptz default now() not null,
  constraint rounds_status check (status in ('gösterge_selection', 'playing', 'finished'))
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

-- ─── REALTIME ────────────────────────────────────────────────────────────────
-- Enable realtime for lobby + round screens
alter publication supabase_realtime add table public.tables;
alter publication supabase_realtime add table public.table_players;
alter publication supabase_realtime add table public.rounds;

-- ─── SEED: anonymous auth ────────────────────────────────────────────────────
-- Make sure anon key works without confirmed email
-- (Supabase handles this by default for anonymous sign-ins)
