-- Migration: 004_profile_username_unique.sql
-- RenkliOkeyScout — profiles.username muss unique sein
--
-- Vorher: username konnte mehrfach vergeben werden
-- Nachher: UNIQUE constraint verhindert Doppelvergabe

-- 1. Alte Duplikate entfernen (sicherheitshalber)
DELETE FROM profiles a USING profiles b
WHERE a.id > b.id AND a.username = b.username;

-- 2. Unique Constraint hinzufügen
ALTER TABLE profiles
  ADD CONSTRAINT profiles_username_unique UNIQUE (username);

-- 3. Username NOT NULL (sollte es ohnehin sein)
ALTER TABLE profiles
  ALTER COLUMN username SET NOT NULL;

-- 4. Check constraint: 2-12 Zeichen
ALTER TABLE profiles
  ADD CONSTRAINT profiles_username_length
    CHECK (char_length(username) BETWEEN 2 AND 12);
