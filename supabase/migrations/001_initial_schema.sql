── Huntone — Schema Supabase Cloud (Compatible SupabaseService.swift existant)
── À exécuter dans le SQL Editor du dashboard Supabase

-- ══════════════════════════════════════════════════════════════════════════
-- 1. PROFILES
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username    TEXT UNIQUE NOT NULL CHECK (length(username) >= 2 AND length(username) <= 30),
    display_name TEXT NOT NULL DEFAULT '' CHECK (length(display_name) <= 50),
    color_seed  TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    bio         TEXT DEFAULT '' CHECK (length(bio) <= 160),
    avatar_url  TEXT DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles (username text_pattern_ops);

-- Ajoute les colonnes manquantes si la table existait déjà
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS color_seed TEXT NOT NULL DEFAULT gen_random_uuid()::text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio        TEXT DEFAULT '' CHECK (length(bio) <= 160);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.friendships ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.frame_posts ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.frame_posts ADD COLUMN IF NOT EXISTS updated_at   TIMESTAMPTZ DEFAULT now();

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Profiles are viewable by everyone' AND tablename = 'profiles') THEN
        CREATE POLICY "Profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert their own profile' AND tablename = 'profiles') THEN
        CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update their own profile' AND tablename = 'profiles') THEN
        CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete their own profile' AND tablename = 'profiles') THEN
        CREATE POLICY "Users can delete their own profile" ON public.profiles FOR DELETE USING (auth.uid() = id);
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════
-- 2. FRIENDSHIPS
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.friendships (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    requester_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    addressee_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    requester_name  TEXT NOT NULL DEFAULT '',
    status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(requester_id, addressee_id)
);

ALTER TABLE public.friendships DROP CONSTRAINT IF EXISTS no_self_request;
DO $$ BEGIN
    ALTER TABLE public.friendships ADD CONSTRAINT no_self_request CHECK (requester_id != addressee_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON public.friendships (addressee_id, status);
CREATE INDEX IF NOT EXISTS idx_friendships_requester ON public.friendships (requester_id, status);

DROP TRIGGER IF EXISTS friendships_updated_at ON public.friendships;
CREATE TRIGGER friendships_updated_at
    BEFORE UPDATE ON public.friendships
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own friendships' AND tablename = 'friendships') THEN
        CREATE POLICY "Users can view their own friendships"
            ON public.friendships FOR SELECT
            USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can create friendship requests' AND tablename = 'friendships') THEN
        CREATE POLICY "Users can create friendship requests"
            ON public.friendships FOR INSERT
            WITH CHECK (auth.uid() = requester_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update their own friendships' AND tablename = 'friendships') THEN
        CREATE POLICY "Users can update their own friendships"
            ON public.friendships FOR UPDATE
            USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════
-- 3. FRAME POSTS
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.frame_posts (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    owner_name  TEXT NOT NULL DEFAULT '',
    date_key    TEXT NOT NULL,
    color_name  TEXT NOT NULL,
    color_hex   TEXT NOT NULL CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
    caption     TEXT DEFAULT '' CHECK (length(caption) <= 500),
    image_urls  TEXT[] NOT NULL DEFAULT '{}',
    likes_count INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(owner_id, date_key)
);

CREATE INDEX IF NOT EXISTS idx_frame_posts_created ON public.frame_posts (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_frame_posts_owner   ON public.frame_posts (owner_id, date_key);

DROP TRIGGER IF EXISTS frame_posts_updated_at ON public.frame_posts;
CREATE TRIGGER frame_posts_updated_at
    BEFORE UPDATE ON public.frame_posts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.frame_posts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Frame posts are viewable by everyone' AND tablename = 'frame_posts') THEN
        CREATE POLICY "Frame posts are viewable by everyone" ON public.frame_posts FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert their own frame posts' AND tablename = 'frame_posts') THEN
        CREATE POLICY "Users can insert their own frame posts" ON public.frame_posts FOR INSERT WITH CHECK (auth.uid() = owner_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update their own frame posts' AND tablename = 'frame_posts') THEN
        CREATE POLICY "Users can update their own frame posts" ON public.frame_posts FOR UPDATE USING (auth.uid() = owner_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete their own frame posts' AND tablename = 'frame_posts') THEN
        CREATE POLICY "Users can delete their own frame posts" ON public.frame_posts FOR DELETE USING (auth.uid() = owner_id);
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════
-- 4. FRAME IMAGES
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.frame_images (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    frame_id     BIGINT NOT NULL REFERENCES public.frame_posts(id) ON DELETE CASCADE,
    position     INTEGER NOT NULL CHECK (position BETWEEN 0 AND 8),
    storage_path TEXT NOT NULL,
    width        INTEGER,
    height       INTEGER,
    file_size    BIGINT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(frame_id, position)
);

CREATE INDEX IF NOT EXISTS idx_frame_images_frame ON public.frame_images(frame_id);

ALTER TABLE public.frame_images ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Frame images are viewable by everyone' AND tablename = 'frame_images') THEN
        CREATE POLICY "Frame images are viewable by everyone" ON public.frame_images FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Owners can insert frame images' AND tablename = 'frame_images') THEN
        CREATE POLICY "Owners can insert frame images" ON public.frame_images FOR INSERT WITH CHECK (
            EXISTS (SELECT 1 FROM public.frame_posts WHERE frame_posts.id = frame_images.frame_id AND frame_posts.owner_id = auth.uid())
        );
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Owners can delete frame images' AND tablename = 'frame_images') THEN
        CREATE POLICY "Owners can delete frame images" ON public.frame_images FOR DELETE USING (
            EXISTS (SELECT 1 FROM public.frame_posts WHERE frame_posts.id = frame_images.frame_id AND frame_posts.owner_id = auth.uid())
        );
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════
-- 5. FRAME LIKES
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.frame_likes (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    frame_id   BIGINT NOT NULL REFERENCES public.frame_posts(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(frame_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_frame_likes_frame ON public.frame_likes(frame_id);
CREATE INDEX IF NOT EXISTS idx_frame_likes_user  ON public.frame_likes(user_id);

ALTER TABLE public.frame_likes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Likes are viewable by everyone' AND tablename = 'frame_likes') THEN
        CREATE POLICY "Likes are viewable by everyone" ON public.frame_likes FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can like frames' AND tablename = 'frame_likes') THEN
        CREATE POLICY "Users can like frames" ON public.frame_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can unlike frames' AND tablename = 'frame_likes') THEN
        CREATE POLICY "Users can unlike frames" ON public.frame_likes FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════
-- 6. FRAME COMMENTS
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.frame_comments (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    frame_id   BIGINT NOT NULL REFERENCES public.frame_posts(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    body       TEXT NOT NULL CHECK (length(body) >= 1 AND length(body) <= 500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_frame_comments_frame ON public.frame_comments(frame_id, created_at ASC);

DROP TRIGGER IF EXISTS frame_comments_updated_at ON public.frame_comments;
CREATE TRIGGER frame_comments_updated_at
    BEFORE UPDATE ON public.frame_comments
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.frame_comments ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Comments are viewable by everyone' AND tablename = 'frame_comments') THEN
        CREATE POLICY "Comments are viewable by everyone" ON public.frame_comments FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can comment' AND tablename = 'frame_comments') THEN
        CREATE POLICY "Users can comment" ON public.frame_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can edit their comments' AND tablename = 'frame_comments') THEN
        CREATE POLICY "Users can edit their comments" ON public.frame_comments FOR UPDATE USING (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete their comments' AND tablename = 'frame_comments') THEN
        CREATE POLICY "Users can delete their comments" ON public.frame_comments FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════
-- TRIGGERS
-- ══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substr(NEW.id::text, 1, 8)),
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.sync_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.frame_posts SET likes_count = likes_count + 1 WHERE id = NEW.frame_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.frame_posts SET likes_count = likes_count - 1 WHERE id = OLD.frame_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS frame_likes_sync_insert ON public.frame_likes;
CREATE TRIGGER frame_likes_sync_insert
    AFTER INSERT ON public.frame_likes
    FOR EACH ROW EXECUTE FUNCTION public.sync_likes_count();

DROP TRIGGER IF EXISTS frame_likes_sync_delete ON public.frame_likes;
CREATE TRIGGER frame_likes_sync_delete
    AFTER DELETE ON public.frame_likes
    FOR EACH ROW EXECUTE FUNCTION public.sync_likes_count();

-- ══════════════════════════════════════════════════════════════════════════
-- FONCTIONS
-- ══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.search_users(search_query TEXT)
RETURNS SETOF public.profiles LANGUAGE sql AS $$
    SELECT * FROM public.profiles
    WHERE username ILIKE '%' || search_query || '%'
       OR display_name ILIKE '%' || search_query || '%'
    ORDER BY username ASC LIMIT 20;
$$;

CREATE OR REPLACE FUNCTION public.get_friends(user_id UUID)
RETURNS SETOF public.profiles LANGUAGE sql AS $$
    SELECT p.* FROM public.profiles p WHERE p.id IN (
        SELECT CASE
            WHEN f.requester_id = user_id THEN f.addressee_id
            ELSE f.requester_id
        END
        FROM public.friendships f
        WHERE (f.requester_id = user_id OR f.addressee_id = user_id)
          AND f.status = 'accepted'
    )
    ORDER BY p.display_name ASC;
$$;

CREATE OR REPLACE FUNCTION public.get_feed(
    limit_count INT DEFAULT 30,
    before_date TIMESTAMPTZ DEFAULT now()
)
RETURNS TABLE (
    id BIGINT,
    owner_id UUID,
    owner_name TEXT,
    owner_display_name TEXT,
    owner_avatar_url TEXT,
    date_key TEXT,
    color_name TEXT,
    color_hex TEXT,
    caption TEXT,
    likes_count INTEGER,
    user_has_liked BOOLEAN,
    image_urls TEXT[],
    created_at TIMESTAMPTZ
) LANGUAGE sql AS $$
    SELECT
        fp.id,
        fp.owner_id,
        fp.owner_name,
        p.display_name AS owner_display_name,
        p.avatar_url AS owner_avatar_url,
        fp.date_key,
        fp.color_name,
        fp.color_hex,
        fp.caption,
        fp.likes_count,
        EXISTS (
            SELECT 1 FROM public.frame_likes fl
            WHERE fl.frame_id = fp.id AND fl.user_id = auth.uid()
        ) AS user_has_liked,
        fp.image_urls,
        fp.created_at
    FROM public.frame_posts fp
    JOIN public.profiles p ON p.id = fp.owner_id
    WHERE fp.created_at < before_date
    ORDER BY fp.created_at DESC
    LIMIT limit_count;
$$;