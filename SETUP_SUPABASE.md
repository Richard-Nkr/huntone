# Huntone + Supabase — Guide de mise en place

## 1. Créer ton projet Supabase

1. Va sur [supabase.com](https://supabase.com) → "New project"
2. Choisis le **Free Tier** (500 Mo DB, 1 Go Storage, 50K MAU)
3. Note le **Project URL** et la **anon key** (dans Settings > API)

## 2. Configurer le projet

2. Remplis les placeholders dans `SupabaseConfig.swift` :

```swift
enum SupabaseConfig {
    /// URL de ton projet → dans Settings > API
    static let url = "https://TON-PROJECT-ID.supabase.co"
    
    /// Publishable Key → clé publique format sb_publishable_...
    /// Dashboard Supabase > Settings > API > Publishable Key
    static let publishableKey = "sb_publishable_xxxxxxxxxxxx"
}
```

## 3. Créer les tables SQL

Ouvre le **SQL Editor** dans le dashboard Supabase et colle le contenu de :

```
supabase/migrations/001_initial_schema.sql
```

Ça crée :
- `profiles` — profils utilisateurs (lié à auth.users, trigger auto au signup)
- `friendships` — demandes d'amis (pending/accepted)
- `frame_posts` — publications de frames (9 URLs d'images)

## 4. Créer le bucket Storage

1. Dashboard Supabase > **Storage** > "New bucket"
2. Nom : `frame-images`
3. ✅ **Public bucket**
4. Dans **Policies** :
   - `SELECT` → `true` (lecture publique)
   - `INSERT` → `auth.uid() = owner` (upload authentifié)

## 5. Ajouter le package Swift

Dans Xcode :
1. **File > Add Packages...**
2. URL : `https://github.com/supabase/supabase-swift`
3. Dependency Rule : "Up to Next Major" ≥ 2.0.0
4. **Add Package**

> Le code de `SupabaseService.swift` utilise l'API REST directement (URLSession).
> Tu peux aussi utiliser le SDK officiel `import Supabase` après avoir ajouté le package :
> ```swift
> let client = SupabaseClient(supabaseURL: URL(string: SupabaseConfig.url)!, supabaseKey: SupabaseConfig.anonKey)
> ```

## 6. Authentification

Par défaut, Supabase utilise l'auth email/password. Configure dans **Authentication > Settings** :
- **Enable email confirmations** → ON (recommendé) ou OFF (pour le dev)
- **Site URL** → URL de ton app

### Options d'auth supplémentaires (dashboard Supabase > Auth > Providers) :
- Apple Sign In (recommandé pour iOS)
- Magic Link
- OTP SMS

## 7. Lancer l'app

```bash
# Ouvre le projet dans Xcode
open Huntone.xcodeproj
```

L'app initialise `SupabaseService` au lancement (`HuntoneApp.swift`).
La session est persistée dans `UserDefaults`.

## Architecture

```
Supabase Cloud (Free Tier)
├── Auth (email/password, Apple, Magic Link)
├── Database (PostgreSQL via PostgREST)
│   ├── profiles
│   ├── friendships
│   └── frame_posts
└── Storage
    └── frame-images/

App iOS (Swift)
├── SupabaseConfig.swift       → URL + publishable key
├── SupabaseService.swift      → REST client (auth, CRUD, upload)
└── HuntoneApp.swift           → init + restore session
```

## Coexistence CloudKit ↔ Supabase

L'app garde `CloudKitService` et `SocialViewModel` en parallèle.
Tu peux basculer progressivement :
- CloudKit → pour les utilisateurs Apple-only (zero-config)
- Supabase → pour le cross-platform, plus de contrôle, analytics
