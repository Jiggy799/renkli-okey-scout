-- ============================================================
-- OkeyScout — Initial Database Schema
-- Run with: supabase db push  OR  via Supabase Dashboard
-- ============================================================

-- Enable UUID generation
create extension if not exists "pgcrypto";

-- ────────────────────────────────────────────────────────────
-- PROFILES (extends auth.users)
-- ────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text not null,
  avatar_url  text,
  created_at  timestamptz not null default now()
);

-- Auto-create profile on sign-up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'username',
      'Spieler_' || substr(new.id::text, 1, 4)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ────────────────────────────────────────────────────────────
-- ANONYMOUS AUTH
-- Note: auth.users RLS is managed by Supabase Auth directly.
-- Enable anonymous sign-ins via: supabase config set auth.enable_anonymous_sign_ins=true
-- or in the Supabase Dashboard under Authentication > Providers > Anonymous Sign-ins.
--
-- The anonymous sign-in policy below is for the public schema only (not auth.users).
-- create policy "Allow anonymous sign-in" on auth.users for insert with check (true);
--
-- ────────────────────────────────────────────────────────────
-- TABLES
-- ────────────────────────────────────────────────────────────
create table if not exists public.tables (
  id              text primary key,  -- 4-digit code, e.g. '4821'
  status          text not null default 'lobby'
                  check (status in ('lobby', 'playing', 'finished')),
  current_round   integer not null default 0,
  gösterge_tile   jsonb,           -- GöstergeTile { color, number }
  created_by      uuid references public.profiles(id),
  created_at      timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────
-- TABLE_PLAYERS
-- ────────────────────────────────────────────────────────────
create table if not exists public.table_players (
  id          uuid primary key default gen_random_uuid(),
  table_id    text not null references public.tables(id) on delete cascade,
  player_id   uuid not null references public.profiles(id) on delete cascade,
  seat_index  integer not null check (seat_index between 0 and 3),
  is_ready    boolean not null default false,
  is_creator  boolean not null default false,
  joined_at   timestamptz not null default now(),
  unique (table_id, player_id),
  unique (table_id, seat_index)
);

-- ────────────────────────────────────────────────────────────
-- ROUNDS
-- ────────────────────────────────────────────────────────────
create table if not exists public.rounds (
  id                       uuid primary key default gen_random_uuid(),
  table_id                 text not null references public.tables(id) on delete cascade,
  round_number             integer not null,
  gösterge_tile            jsonb not null,   -- GöstergeTile { color, number }
  gösterge_player_id       uuid references public.profiles(id),
  gösterge_confirmed       boolean not null default false,
  gösterge_confirmed_by    uuid references public.profiles(id),
  status                   text not null default 'gösterge_selection'
                            check (status in ('gösterge_selection', 'playing', 'finished')),
  winner_id                uuid references public.profiles(id),
  started_at               timestamptz,
  finished_at              timestamptz,
  created_at               timestamptz not null default now(),
  unique (table_id, round_number)
);

-- ────────────────────────────────────────────────────────────
-- ROUND_HANDS  (persisted scan results per player per round)
-- ────────────────────────────────────────────────────────────
create table if not exists public.round_hands (
  id              uuid primary key default gen_random_uuid(),
  round_id        uuid not null references public.rounds(id) on delete cascade,
  player_id       uuid not null references public.profiles(id) on delete cascade,
  tiles           jsonb not null,   -- Tile[]  [{ color, number, isFalseOkey }]
  discarded_tile  jsonb,            -- Tile | null (for pairs win)
  score           integer,
  win_type        text check (win_type in ('NORMAL', 'OKEY', 'PAIRS')),
  is_false_finish boolean default false,
  submitted_at     timestamptz not null default now(),
  unique (round_id, player_id)
);

-- ────────────────────────────────────────────────────────────
-- REALTIME  (enable for all tables)
-- ────────────────────────────────────────────────────────────
alter publication supabase_realtime add table public.tables;
alter publication supabase_realtime add table public.table_players;
alter publication supabase_realtime add table public.rounds;

-- ────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────
alter table public.profiles    enable row level security;
alter table public.tables      enable row level security;
alter table public.table_players enable row level security;
alter table public.rounds      enable row level security;
alter table public.round_hands enable row level security;

-- Profiles: anyone can read, only owner can update
create policy "Profiles are publicly readable"
  on public.profiles for select using (true);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert with check (auth.uid() = id);

-- Tables: anyone can read; only participants can modify
create policy "Tables are publicly readable"
  on public.tables for select using (true);

create policy "Authenticated users can create tables"
  on public.tables for insert with check (auth.uid() is not null);

create policy "Players can update their table"
  on public.tables for update using (
    exists (
      select 1 from public.table_players
      where table_id = public.tables.id and player_id = auth.uid()
    )
  );

-- Table players: readable by all; join/leave managed by participants
create policy "Table players are publicly readable"
  on public.table_players for select using (true);

create policy "Authenticated users can join a table"
  on public.table_players for insert
  with check (auth.uid() = player_id);

create policy "Players can update own player record"
  on public.table_players for update using (auth.uid() = player_id);

create policy "Players can leave a table"
  on public.table_players for delete using (auth.uid() = player_id);

-- Rounds: readable by table participants
create policy "Rounds are publicly readable"
  on public.rounds for select using (true);

create policy "Authenticated users can create rounds"
  on public.rounds for insert with check (auth.uid() is not null);

create policy "Players can update rounds for their table"
  on public.rounds for update using (
    exists (
      select 1 from public.table_players
      where table_id = public.rounds.table_id and player_id = auth.uid()
    )
  );

-- Round hands: only the player themselves can see/manage their hand
create policy "Players can read own round hand"
  on public.round_hands for select using (auth.uid() = player_id);

create policy "Players can submit own hand"
  on public.round_hands for insert
  with check (auth.uid() = player_id);

create policy "Players can update own round hand"
  on public.round_hands for update using (auth.uid() = player_id);
