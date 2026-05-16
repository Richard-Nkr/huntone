import Foundation

/// Configuration Supabase — remplace les placeholders par les valeurs de ton projet
/// Disponibles dans le dashboard Supabase : Settings > API
enum SupabaseConfig {
    /// URL de ton projet Supabase (ex: "https://abcdefghijklm.supabase.co")
    static let url = "https://inaaarwomalmaxyipllr.supabase.co"

    /// Clé publique "publishable" — REMPLACE avec la vraie clé depuis :
    /// Supabase Dashboard → Settings → API → Publishable Key
    /// La clé complète fait ~200 caractères (format JWT)
    /// ⚠️ VÉRIFIE que la clé ci-dessous est COMPLÈTE (pas tronquée) :
    static let publishableKey = "sb_publishable_61M1_2El528O_VAIX0C6SQ_rq7jbeV_"

    /// Clé secrète "service_role" — NE JAMAIS inclure dans le binaire client
    /// Usage : backend/admin uniquement
    static let serviceRoleKey = "sb_secret_..."

    /// Bucket Storage pour les photos des frames
    static let framesBucket = "frame-images"

    /// Taille max d'upload (50 Mo)
    static let maxUploadSize = 52_428_800

    /// Préfixe pour les clés de UserDefaults liées à Supabase
    static let defaultsPrefix = "huntone.supabase"
}
