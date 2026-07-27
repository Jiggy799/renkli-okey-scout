-- Migration 006: Gösterge-Bestätigung für Online-Modus
--
-- Im Demo-Modus haben wir `gostergeConfirmedBy` Set lokal.
-- Für Online-Modus braucht es eine Spalte in der rounds-Tabelle.
--
-- Format: JSONB Array von Player-UUIDs.
-- Locked = wenn Array length >= 2.
-- Wenn locked, kann der Gösterge nicht mehr geändert werden.

ALTER TABLE rounds
  ADD COLUMN IF NOT EXISTS gosterge_confirmed_by jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Constraint: Maximal 4 Spieler können bestätigen (wir haben max 4 Plätze)
ALTER TABLE rounds
  DROP CONSTRAINT IF EXISTS rounds_gosterge_confirmers_max;
ALTER TABLE rounds
  ADD CONSTRAINT rounds_gosterge_confirmers_max
    CHECK (jsonb_array_length(gosterge_confirmed_by) <= 4);

-- Comment für Doku
COMMENT ON COLUMN rounds.gosterge_confirmed_by IS
  'Array von Player-UUIDs die den Gösterge bestätigt haben. Locked ab 2 Bestätigungen.';