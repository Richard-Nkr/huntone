# Huntone Backend — Supabase Self-Hosted

## Déploiement sur VPS

### Prérequis
- Docker & Docker Compose
- Node.js (pour générer les clés JWT)
- Un VPS avec Ubuntu 22.04+ recommandé

### Installation rapide

```bash
cd backend
./deploy.sh votre-domaine.com
```

### Installation manuelle

```bash
cd backend

# Copier les variables d'environnement
cp .env.example .env

# Générer les secrets
openssl rand -base64 32  # -> JWT_SECRET

# Clés JWT : utiliser node pour générer ANON_KEY et SERVICE_ROLE_KEY
# ou https://jwt.io avec le secret ci-dessus
# Payload ANON_KEY  : { "iss": "supabase", "ref": "huntone", "role": "anon", "iat": ..., "exp": ... }
# Payload SERVICE_KEY : { "iss": "supabase", "ref": "huntone", "role": "service_role", "iat": ..., "exp": ... }

# Éditer .env avec les bonnes valeurs
vim .env

# Démarrer
docker compose up -d
```

### Initialiser les buckets

```bash
docker compose exec db psql -U postgres -d huntone \
  -c "INSERT INTO storage.buckets (id, name, public, file_size_limit) VALUES ('frame-images', 'frame-images', true, 52428800) ON CONFLICT DO NOTHING;"

docker compose exec db psql -U postgres -d huntone \
  -c "INSERT INTO storage.buckets (id, name, public, file_size_limit) VALUES ('avatars', 'avatars', true, 5242880) ON CONFLICT DO NOTHING;"
```

### URLs après déploiement

| Service      | URL                          |
|-------------|------------------------------|
| API         | `http://vps:8000`           |
| Studio      | `http://vps:3000`           |
| PostgreSQL  | `localhost:5432` (interne)  |

### Configurer l'app iOS

Dans `SupabaseClient.swift`, remplacer :
- `VOTRE_VPS` par l'IP/domaine de ton VPS
- `VOTRE_ANON_KEY` par la clé ANON_KEY générée

### Structure de l'API

```
POST   /auth/v1/signup              — Inscription email/password
POST   /auth/v1/token               — Connexion (grant_type=password)
GET    /rest/v1/profiles            — Profils utilisateurs
POST   /rest/v1/profiles            — Créer profil (upsert)
GET    /rest/v1/friendships         — Relations amis
POST   /rest/v1/frame_posts         — Publier un frame
GET    /rest/v1/rpc/get_feed        — Feed des frames
POST   /storage/v1/object/{bucket}  — Upload image
GET    /storage/v1/object/public/{bucket}/{path} — Image publique
```

### Commandes utiles

```bash
docker compose ps              # Vérifier les conteneurs
docker compose logs -f auth    # Logs auth
docker compose logs -f storage # Logs stockage
docker compose restart         # Redémarrer tout
docker compose down -v         # Tout arrêter + supprimer volumes
```

### Architecture des services

```
Client (iOS) → Kong (API Gateway :8000)
                ├── /auth/v1   → GoTrue (auth)
                ├── /rest/v1   → PostgREST (API PostgreSQL)
                ├── /storage/v1 → Storage API (images)
                └── /realtime/v1 → Realtime (WebSocket)
```
