-- ============================================================================
-- Huntone — Migration Supabase initiale
-- À exécuter dans le SQL Editor du dashboard Supabase
-- ============================================================================

-- 1. PROFILS
-- Stocke les profils utilisateurs (liés à auth.users)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username    TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ
);

-- Index pour la recherche par username
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles (username text_pattern_ops);

-- Trigger : création automatique du profil au signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substr(NEW.id::text, 1, 8)),
        COALESCE(NEW.raw_user_meta_data->>'display_name', '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- RLS : lecture publique, écriture par le propriétaire
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles are viewable by everyone"
    ON public.profiles FOR SELECT
    USING (true);

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- ============================================================================
-- 2. FRIENDSHIPS
-- Demandes d'amis et statut (pending, accepted)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.friendships (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    requester_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    addressee_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    requester_name  TEXT NOT NULL DEFAULT '',
    status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ,

    UNIQUE(requester_id, addressee_id)
);

-- Empêche de s'envoyer une demande à soi-même
ALTER TABLE public.friendships ADD CONSTRAINT no_self_request
    CHECK (requester_id != addressee_id);

CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON public.friendships (addressee_id, status);
CREATE INDEX IF NOT EXISTS idx_friendships_requester ON public.friendships (requester_id, status);

-- RLS
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own friendships"
    ON public.friendships FOR SELECT
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

CREATE POLICY "Users can create friendship requests"
    ON public.friendships FOR INSERT
    WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Users can update their own friendships"
    ON public.friendships FOR UPDATE
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- ============================================================================
-- 3. FRAME POSTS
-- Publications de frames (9 photos + métadonnées couleur)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.frame_posts (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    owner_name  TEXT NOT NULL DEFAULT '',
    date_key    TEXT NOT NULL,       -- "2026-05-04"
    color_name  TEXT NOT NULL,       -- "Cobalt"
    color_hex   TEXT NOT NULL,       -- "#2667FF"
    caption     TEXT NOT NULL DEFAULT '',
    image_urls  TEXT[] NOT NULL DEFAULT '{}',  -- tableau des 9 URLs Storage
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(owner_id, date_key)
);

CREATE INDEX IF NOT EXISTS idx_frame_posts_created ON public.frame_posts (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_frame_posts_owner ON public.frame_posts (owner_id, date_key);

-- RLS : lecture publique, écriture par le propriétaire
ALTER TABLE public.frame_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Frame posts are viewable by everyone"
    ON public.frame_posts FOR SELECT
    USING (true);

CREATE POLICY "Users can insert their own frame posts"
    ON public.frame_posts FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update their own frame posts"
    ON public.frame_posts FOR UPDATE
    USING (auth.uid() = owner_id);

-- ============================================================================
-- 4. STORAGE BUCKET
-- À créer via le dashboard Supabase > Storage, ou via SQL :
-- ============================================================================

-- Crée le bucket (exécuter séparément si le dashboard ne supporte pas les extensions storage)
-- SELECT storage.create_bucket('frame-images', '{"public": true}');

-- RLS pour le bucket (à appliquer manuellement dans Storage > Policies)
-- Policy "Public read access" : SELECT pour tout le monde
-- Policy "Authenticated upload" : INSERT pour auth.uid() = owner
