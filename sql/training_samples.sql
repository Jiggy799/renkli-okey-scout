-- ============================================================
-- RenkliOkeyScout — Training Samples Table
-- ============================================================
-- Run this in Supabase SQL Editor:
--   https://ntssssvyyptvdjerbtll.supabase.co/project/_/sql/new
-- ============================================================

-- 1. Table for training samples metadata
CREATE TABLE IF NOT EXISTS public.training_samples (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    uploader_id  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    image_path   text NOT NULL,
    image_url    text NOT NULL,
    gosterge_color text,                       -- yellow | blue | red | black | null
    gosterge_number int,                       -- 1..13 | null
    tiles        jsonb NOT NULL DEFAULT '[]'::jsonb,
    notes        text,
    tile_count   int NOT NULL DEFAULT 0,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_training_samples_created_at
    ON public.training_samples (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_training_samples_uploader
    ON public.training_samples (uploader_id);

-- 2. Row Level Security
ALTER TABLE public.training_samples ENABLE ROW LEVEL SECURITY;

-- Anyone (incl. anon) can insert
DROP POLICY IF EXISTS "anon_insert_training_samples" ON public.training_samples;
CREATE POLICY "anon_insert_training_samples"
    ON public.training_samples FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

-- Anyone can read (so the progress counter works)
DROP POLICY IF EXISTS "anon_read_training_samples" ON public.training_samples;
CREATE POLICY "anon_read_training_samples"
    ON public.training_samples FOR SELECT
    TO anon, authenticated
    USING (true);

-- Only owner can delete their own
DROP POLICY IF EXISTS "owner_delete_training_samples" ON public.training_samples;
CREATE POLICY "owner_delete_training_samples"
    ON public.training_samples FOR DELETE
    TO authenticated
    USING (auth.uid() = uploader_id);

-- ============================================================
-- 3. Storage bucket: training-data
-- ============================================================
-- Create via Dashboard: Storage → New bucket → name: training-data
-- Public bucket (so image_url works)
-- Then run:
-- ============================================================

DROP POLICY IF EXISTS "anon_upload_training" ON storage.objects;
CREATE POLICY "anon_upload_training"
    ON storage.objects FOR INSERT
    TO anon, authenticated
    WITH CHECK (bucket_id = 'training-data');

DROP POLICY IF EXISTS "anon_read_training" ON storage.objects;
CREATE POLICY "anon_read_training"
    ON storage.objects FOR SELECT
    TO anon, authenticated
    USING (bucket_id = 'training-data');
