-- Huntone — Ajout du telephone + recherche etendue
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '';
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles (phone);
