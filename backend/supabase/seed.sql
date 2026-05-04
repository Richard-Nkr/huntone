── Huntone Seed Data ───────────────────────────────────────────────────────
── À exécuter dans le Studio Supabase ou via psql en développement

-- Insérer le bucket de stockage "frame-images"
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'frame-images',
    'frame-images',
    true,
    52428800,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
) ON CONFLICT (id) DO NOTHING;

-- Insérer le bucket "avatars"
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
) ON CONFLICT (id) DO NOTHING;
