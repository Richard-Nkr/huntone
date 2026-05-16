-- Huntone — Création bucket + RLS Storage
-- À exécuter dans le SQL Editor du dashboard Supabase

-- 1. Crée le bucket (ignoré s'il existe déjà)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'frame-images',
    'frame-images',
    true,
    52428800,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Policies RLS sur storage.objects

-- Lecture publique (tout le monde peut voir les photos)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public read frame-images' AND tablename = 'objects' AND schemaname = 'storage') THEN
        CREATE POLICY "Public read frame-images"
            ON storage.objects FOR SELECT
            USING (bucket_id = 'frame-images');
    END IF;
END $$;

-- Upload : seuls les utilisateurs auth peuvent uploader dans leur dossier (1er segment du path = auth.uid())
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Auth users can upload to frame-images' AND tablename = 'objects' AND schemaname = 'storage') THEN
        CREATE POLICY "Auth users can upload to frame-images"
            ON storage.objects FOR INSERT
            WITH CHECK (
                bucket_id = 'frame-images'
                AND auth.role() = 'authenticated'
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;
END $$;

-- Update : seul le propriétaire peut modifier
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Auth users can update own frame-images' AND tablename = 'objects' AND schemaname = 'storage') THEN
        CREATE POLICY "Auth users can update own frame-images"
            ON storage.objects FOR UPDATE
            USING (
                bucket_id = 'frame-images'
                AND auth.role() = 'authenticated'
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;
END $$;

-- Delete : seul le propriétaire peut supprimer
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Auth users can delete own frame-images' AND tablename = 'objects' AND schemaname = 'storage') THEN
        CREATE POLICY "Auth users can delete own frame-images"
            ON storage.objects FOR DELETE
            USING (
                bucket_id = 'frame-images'
                AND auth.role() = 'authenticated'
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;
END $$;
