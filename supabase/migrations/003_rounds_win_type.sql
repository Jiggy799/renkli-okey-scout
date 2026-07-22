-- Migration 003: Replace joker_finish (boolean) with win_type (text enum)
-- joker_finish was: true/false (only Joker ×2)
-- win_type now supports: normal | okey | cifte | okeyCifte
--
-- Joker ×2 + Cifte ×2 = okeyCifte ×4 (max ×20 with Schwarz)

alter table public.rounds drop column if exists joker_finish;
alter table public.rounds add column if not exists win_type text not null default 'normal'
  constraint rounds_win_type check (win_type in ('normal', 'okey', 'cifte', 'okeyCifte'));
