-- Migration 002: Add missing game-tracking columns to table_players
-- Flutter app expects: is_cifte, cumulative_penalty on table_players

alter table public.table_players add column if not exists is_cifte boolean not null default false;
alter table public.table_players add column if not exists cumulative_penalty integer not null default 0;
