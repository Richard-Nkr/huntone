-- Huntone — Ajout des transforms d'image pour le feed
-- À exécuter dans le SQL Editor du dashboard Supabase

ALTER TABLE public.frame_posts
ADD COLUMN IF NOT EXISTS image_transforms JSONB[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN public.frame_posts.image_transforms IS 'Transforms for each of 9 images: [{ox, oy, scale}, ...]';
