-- Huntone — Création bucket avatars + RLS
-- À exécuter dans le SQL Editor du dashboard Supabase

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Lecture publique
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public read avatars' AND tablename = 'objects' AND schemaname = 'storage') THEN
        CREATE POLICY "Public read avatars"
            ON storage.objects FOR SELECT
            USING (bucket_id = 'avatars');
    END IF;
END $$;

-- Upload : seul l'utilisateur auth peut uploader dans son dossier
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Auth users can upload avatars' AND tablename = 'objects' AND schemaname = 'storage') THEN
        CREATE POLICY "Auth users can upload avatars"
            ON storage.objects FOR INSERT
            WITH CHECK (
                bucket_id = 'avatars'
                AND auth.role() = 'authenticated'
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;
END $$;

-- Update par le propriétaire
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Auth users can update own avatars' AND tablename = 'objects' AND schemaname = 'storage') THEN
        CREATE POLICY "Auth users can update own avatars"
            ON storage.objects FOR UPDATE
            USING (
                bucket_id = 'avatars'
                AND auth.role() = 'authenticated'
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;
END $$;
