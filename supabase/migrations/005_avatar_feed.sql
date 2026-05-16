ALTER TABLE public.frame_posts
ADD COLUMN IF NOT EXISTS owner_avatar_url TEXT DEFAULT '';
