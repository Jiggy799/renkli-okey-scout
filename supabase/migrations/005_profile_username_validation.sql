-- Migration 005: profile_username_validation
-- Username muss 2-12 Zeichen haben + NOT NULL

-- 1. Optional: Username muss 2-12 Zeichen haben
ALTER TABLE profiles
  DROP CONSTRAINT IF EXISTS profiles_username_length;
ALTER TABLE profiles
  ADD CONSTRAINT profiles_username_length
    CHECK (char_length(username) BETWEEN 2 AND 12);

-- 2. Username NOT NULL
ALTER TABLE profiles
  ALTER COLUMN username SET NOT NULL;
