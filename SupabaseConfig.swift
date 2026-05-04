import Foundation

/// Configuration Supabase — remplace les placeholders par les valeurs de ton projet
/// Disponibles dans le dashboard Supabase : Settings > API
enum SupabaseConfig {
    /// URL de ton projet Supabase (ex: "https://abcdefghijklm.supabase.co")
    static let url = "https://TON-PROJECT-ID.supabase.co"

    /// Clé publique "anon" (utilisable côté client, Row Level Security activé)
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

    /// Bucket Storage pour les photos des frames
    static let framesBucket = "frame-images"

    /// Taille max d'upload (50 Mo)
    static let maxUploadSize = 52_428_800

    /// Préfixe pour les clés de UserDefaults liées à Supabase
    static let defaultsPrefix = "huntone.supabase"
}
