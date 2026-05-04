import Foundation

/// Configuration Supabase — remplace les placeholders par les valeurs de ton projet
/// Disponibles dans le dashboard Supabase : Settings > API
enum SupabaseConfig {
    /// URL de ton projet Supabase (ex: "https://abcdefghijklm.supabase.co")
    static let url = "https://TON-PROJECT-ID.supabase.co"

    /// Clé publique "publishable" (utilisable côté client, Row Level Security activé)
    /// Format : sb_publishable_xxxxxxxxxxxx
    /// Disponible dans Supabase Dashboard > Settings > API > Publishable Key
    static let publishableKey = "sb_publishable_67wIRAWNXINuB8crvtD1Mg_Sal_f0-c"

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
