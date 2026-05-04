── Huntone Database Schema ────────────────────────────────────────────────
── Version 1.0.0
──
── Tables:  profiles, friendships, frame_posts, frame_images
── Schema:  public (app) + storage (bucket metadata)
── Auth:    managed by GoTrue (auth.users)

-- ── Extensions ────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pgjwt";

-- ── Roles ─────────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator LOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
        CREATE ROLE supabase_auth_admin LOGIN CREATEROLE NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
        CREATE ROLE supabase_storage_admin LOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
    END IF;
END $$;

GRANT anon              TO authenticator;
GRANT authenticated     TO authenticator;
GRANT service_role      TO authenticator;
GRANT supabase_auth_admin TO authenticator;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES    TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

-- ── Auth Schema (GoTrue) ─────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS auth;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON TABLES TO supabase_auth_admin;

-- ──────────────────────────────────────────────────────────────────────────
-- TABLES PUBLIQUES
-- ──────────────────────────────────────────────────────────────────────────

-- ── Profiles ──────────────────────────────────────────────────────────────
CREATE TABLE public.profiles (
    id          UUID PRIMARY KEY,
    username    TEXT UNIQUE NOT NULL CHECK (length(username) >= 2 AND length(username) <= 30),
    display_name TEXT NOT NULL CHECK (length(display_name) >= 1 AND length(display_name) <= 50),
    bio         TEXT DEFAULT '' CHECK (length(bio) <= 160),
    avatar_url  TEXT DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'Profils utilisateurs Huntone';
COMMENT ON COLUMN public.profiles.username IS 'Identifiant unique (lowercase, sans @)';

-- ── Friendships ───────────────────────────────────────────────────────────
CREATE TABLE public.friendships (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    addressee_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT different_users CHECK (requester_id <> addressee_id),
    CONSTRAINT unique_friendship UNIQUE (requester_id, addressee_id)
);

CREATE INDEX idx_friendships_addressee ON public.friendships(addressee_id, status);
CREATE INDEX idx_friendships_requester ON public.friendships(requester_id, status);

COMMENT ON TABLE public.friendships IS 'Relations entre utilisateurs';

-- ── Frame Posts ───────────────────────────────────────────────────────────
CREATE TABLE public.frame_posts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    date_key    TEXT NOT NULL,
    color_name  TEXT NOT NULL,
    color_hex   TEXT NOT NULL CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
    caption     TEXT DEFAULT '' CHECK (length(caption) <= 500),
    likes_count INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_frame_posts_owner   ON public.frame_posts(owner_id);
CREATE INDEX idx_frame_posts_created ON public.frame_posts(created_at DESC);
CREATE INDEX idx_frame_posts_feed    ON public.frame_posts(created_at DESC) INCLUDE (owner_id, caption);

COMMENT ON TABLE public.frame_posts IS 'Frames 3×3 publies par les utilisateurs';

-- ── Frame Images ──────────────────────────────────────────────────────────
CREATE TABLE public.frame_images (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    frame_id     UUID NOT NULL REFERENCES public.frame_posts(id) ON DELETE CASCADE,
    position     INTEGER NOT NULL CHECK (position BETWEEN 0 AND 8),
    storage_path TEXT NOT NULL,
    width        INTEGER,
    height       INTEGER,
    file_size    BIGINT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (frame_id, position)
);

CREATE INDEX idx_frame_images_frame ON public.frame_images(frame_id);

COMMENT ON TABLE public.frame_images IS 'Images individuelles d''un frame (0-8)';

-- ── Likes ─────────────────────────────────────────────────────────────────
CREATE TABLE public.frame_likes (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    frame_id   UUID NOT NULL REFERENCES public.frame_posts(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (frame_id, user_id)
);

CREATE INDEX idx_frame_likes_frame ON public.frame_likes(frame_id);
CREATE INDEX idx_frame_likes_user  ON public.frame_likes(user_id);

-- ── Comments ──────────────────────────────────────────────────────────────
CREATE TABLE public.frame_comments (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    frame_id   UUID NOT NULL REFERENCES public.frame_posts(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    body       TEXT NOT NULL CHECK (length(body) >= 1 AND length(body) <= 500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_frame_comments_frame ON public.frame_comments(frame_id, created_at ASC);

-- ──────────────────────────────────────────────────────────────────────────
-- STORAGE SCHEMA
-- ──────────────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS storage;
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role, supabase_storage_admin;

CREATE TABLE IF NOT EXISTS storage.buckets (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    owner       UUID REFERENCES auth.users(id),
    public      BOOLEAN DEFAULT false,
    file_size_limit BIGINT DEFAULT 52428800,
    allowed_mime_types TEXT[] DEFAULT '{"image/jpeg","image/png","image/webp","image/heic","image/heif"}',
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS storage.objects (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bucket_id   TEXT NOT NULL REFERENCES storage.buckets(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    owner       UUID REFERENCES auth.users(id),
    metadata    JSONB DEFAULT '{}'::jsonb,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now(),
    last_accessed_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (bucket_id, name)
);

CREATE INDEX IF NOT EXISTS idx_storage_objects_bucket ON storage.objects(bucket_id, name);

GRANT ALL ON ALL TABLES    IN SCHEMA storage TO supabase_storage_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO supabase_storage_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL ON TABLES    TO supabase_storage_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL ON SEQUENCES TO supabase_storage_admin;

-- ──────────────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ──────────────────────────────────────────────────────────────────────────

ALTER TABLE public.profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.frame_posts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.frame_images    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.frame_likes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.frame_comments  ENABLE ROW LEVEL SECURITY;

-- ── Profiles ──────────────────────────────────────────────────────────────
-- Lecture : tout le monde peut lire les profils
CREATE POLICY profiles_select ON public.profiles
    FOR SELECT USING (true);

-- Insertion : uniquement son propre profil (via auth.uid())
CREATE POLICY profiles_insert ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Mise à jour : uniquement son propre profil
CREATE POLICY profiles_update ON public.profiles
    FOR UPDATE USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Suppression : uniquement son propre profil
CREATE POLICY profiles_delete ON public.profiles
    FOR DELETE USING (auth.uid() = id);

-- ── Friendships ───────────────────────────────────────────────────────────
-- Lecture : participants uniquement
CREATE POLICY friendships_select ON public.friendships
    FOR SELECT USING (
        auth.uid() = requester_id OR auth.uid() = addressee_id
    );

-- Insertion : l'utilisateur doit être le demandeur
CREATE POLICY friendships_insert ON public.friendships
    FOR INSERT WITH CHECK (auth.uid() = requester_id);

-- Mise à jour : le destinataire peut accepter/bloquer
CREATE POLICY friendships_update ON public.friendships
    FOR UPDATE USING (
        (auth.uid() = requester_id AND status = 'pending')
        OR auth.uid() = addressee_id
    );

-- ── Frame Posts ───────────────────────────────────────────────────────────
-- Lecture : tout le monde peut lire (feed public)
CREATE POLICY frame_posts_select ON public.frame_posts
    FOR SELECT USING (true);

-- Insertion : utilisateur authentifié
CREATE POLICY frame_posts_insert ON public.frame_posts
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- Mise à jour : propriétaire uniquement
CREATE POLICY frame_posts_update ON public.frame_posts
    FOR UPDATE USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

-- Suppression : propriétaire uniquement
CREATE POLICY frame_posts_delete ON public.frame_posts
    FOR DELETE USING (auth.uid() = owner_id);

-- ── Frame Images ──────────────────────────────────────────────────────────
CREATE POLICY frame_images_select ON public.frame_images
    FOR SELECT USING (true);

CREATE POLICY frame_images_insert ON public.frame_images
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.frame_posts
            WHERE frame_posts.id = frame_images.frame_id
              AND frame_posts.owner_id = auth.uid()
        )
    );

CREATE POLICY frame_images_delete ON public.frame_images
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.frame_posts
            WHERE frame_posts.id = frame_images.frame_id
              AND frame_posts.owner_id = auth.uid()
        )
    );

-- ── Likes ─────────────────────────────────────────────────────────────────
CREATE POLICY frame_likes_select ON public.frame_likes
    FOR SELECT USING (true);

CREATE POLICY frame_likes_insert ON public.frame_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY frame_likes_delete ON public.frame_likes
    FOR DELETE USING (auth.uid() = user_id);

-- ── Comments ──────────────────────────────────────────────────────────────
CREATE POLICY frame_comments_select ON public.frame_comments
    FOR SELECT USING (true);

CREATE POLICY frame_comments_insert ON public.frame_comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY frame_comments_update ON public.frame_comments
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY frame_comments_delete ON public.frame_comments
    FOR DELETE USING (auth.uid() = user_id);

-- ──────────────────────────────────────────────────────────────────────────
-- TRIGGERS
-- ──────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER friendships_updated_at
    BEFORE UPDATE ON public.friendships
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER frame_posts_updated_at
    BEFORE UPDATE ON public.frame_posts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER frame_comments_updated_at
    BEFORE UPDATE ON public.frame_comments
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Auto-create profile on signup ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substring(NEW.id::text, 1, 8)),
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: Ce trigger est créé par GoTrue. S'il existe déjà, on ignore.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'on_auth_user_created'
          AND tgrelid = 'auth.users'::regclass
    ) THEN
        CREATE TRIGGER on_auth_user_created
            AFTER INSERT ON auth.users
            FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
    END IF;
END $$;

-- ── Like counter sync ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.frame_posts
        SET likes_count = likes_count + 1
        WHERE id = NEW.frame_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.frame_posts
        SET likes_count = likes_count - 1
        WHERE id = OLD.frame_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER frame_likes_sync_insert
    AFTER INSERT ON public.frame_likes
    FOR EACH ROW EXECUTE FUNCTION public.sync_likes_count();

CREATE TRIGGER frame_likes_sync_delete
    AFTER DELETE ON public.frame_likes
    FOR EACH ROW EXECUTE FUNCTION public.sync_likes_count();

-- ──────────────────────────────────────────────────────────────────────────
-- FONCTIONS UTILITAIRES
-- ──────────────────────────────────────────────────────────────────────────

-- Rechercher des utilisateurs par username
CREATE OR REPLACE FUNCTION public.search_users(search_query TEXT)
RETURNS SETOF public.profiles
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT * FROM public.profiles
    WHERE username ILIKE '%' || search_query || '%'
       OR display_name ILIKE '%' || search_query || '%'
    ORDER BY username ASC
    LIMIT 20;
$$;

-- Récupérer les amis d'un utilisateur
CREATE OR REPLACE FUNCTION public.get_friends(user_id UUID)
RETURNS SETOF public.profiles
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT p.* FROM public.profiles p
    WHERE p.id IN (
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

-- Récupérer le feed (frames récents)
CREATE OR REPLACE FUNCTION public.get_feed(limit_count INT DEFAULT 30, before_date TIMESTAMPTZ DEFAULT now())
RETURNS TABLE (
    id UUID,
    owner_id UUID,
    owner_username TEXT,
    owner_display_name TEXT,
    owner_avatar_url TEXT,
    date_key TEXT,
    color_name TEXT,
    color_hex TEXT,
    caption TEXT,
    likes_count INTEGER,
    user_has_liked BOOLEAN,
    images JSONB,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT
        fp.id,
        fp.owner_id,
        p.username AS owner_username,
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
        COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'position', fi.position,
                    'storage_path', fi.storage_path,
                    'width', fi.width,
                    'height', fi.height
                ) ORDER BY fi.position
            )
            FROM public.frame_images fi
            WHERE fi.frame_id = fp.id),
            '[]'::jsonb
        ) AS images,
        fp.created_at
    FROM public.frame_posts fp
    JOIN public.profiles p ON p.id = fp.owner_id
    WHERE fp.created_at < before_date
    ORDER BY fp.created_at DESC
    LIMIT limit_count;
$$;

-- ── Droits sur les fonctions ──────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.search_users TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_friends   TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_feed      TO anon, authenticated;
