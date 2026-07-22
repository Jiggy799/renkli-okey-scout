-- Migration 002: Public Policies + Anonymous Sign-In Support
-- Fixes: add anon to create-table policy, add gösterge columns

-- Allow ANON (anonymous sign-in) users to create tables
DROP POLICY IF EXISTS "Authenticated users can create tables" ON public.tables;
CREATE POLICY "Anyone can create tables"
  ON public.tables FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Allow ANON to create rounds (for Gösterge selection)
DROP POLICY IF EXISTS "Authenticated users can create rounds" ON public.rounds;
CREATE POLICY "Anyone can create rounds"
  ON public.rounds FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Allow ANON to join tables
DROP POLICY IF EXISTS "Authenticated users can join a table" ON public.table_players;
CREATE POLICY "Anyone can join a table"
  ON public.table_players FOR INSERT
  TO anon, authenticated
  WITH CHECK (auth.uid() = player_id);

-- Allow ANON to insert profiles (auto-created on sign-up via trigger is fine,
-- but this is a fallback in case the trigger hasn't fired yet)
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Anyone can insert own profile"
  ON public.profiles FOR INSERT
  TO anon, authenticated
  WITH CHECK (auth.uid() = id);

-- Gösterge selection: allow table participants to set gösterge
-- (update gösterge_player_id and gösterge_confirmed)
DROP POLICY IF EXISTS "Players can update rounds for their table" ON public.rounds;
CREATE POLICY "Players can update rounds for their table"
  ON public.rounds FOR UPDATE
  TO anon, authenticated
  USING (
    exists (
      select 1 from public.table_players
      where table_id = public.rounds.table_id and player_id = auth.uid()
    )
  );
