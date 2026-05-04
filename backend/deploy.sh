#!/usr/bin/env bash
set -euo pipefail

# ── Huntone VPS Deployment Script ───────────────────────────────────────

echo "🔵 Huntone Backend Deployment"
echo "=============================="

# ── Check prerequisites ─────────────────────────────────────────────────
check_command() {
    if ! command -v "$1" &>/dev/null; then
        echo "❌ $1 n'est pas installé. Installe-le d'abord."
        exit 1
    fi
}

check_command docker
check_command openssl

# ── Generate secrets if not present ─────────────────────────────────────
generate_jwt_keys() {
    echo "🔑 Génération des clés JWT..."

    JWT_SECRET=$(openssl rand -base64 32)

    # Generate ANON_KEY (JWT for anonymous role)
    ANON_KEY=$(node -e "
        const crypto = require('crypto');
        const key = '$JWT_SECRET';
        const header = { alg: 'HS256', typ: 'JWT' };
        const payload = {
            iss: 'supabase',
            ref: 'huntone',
            role: 'anon',
            iat: Math.floor(Date.now() / 1000),
            exp: Math.floor(Date.now() / 1000) + 630720000
        };
        function btoa(s) { return Buffer.from(s).toString('base64url'); }
        const headerB64 = btoa(JSON.stringify(header));
        const payloadB64 = btoa(JSON.stringify(payload));
        const signature = crypto
            .createHmac('sha256', key)
            .update(headerB64 + '.' + payloadB64)
            .digest('base64url');
        console.log(headerB64 + '.' + payloadB64 + '.' + signature);
    " 2>/dev/null || {
        echo "⚠️  Node.js non trouvé pour générer les clés JWT. Génération manuelle nécessaire."
        echo "   Utilise https://jwt.io pour créer les clés ANON_KEY et SERVICE_ROLE_KEY"
        echo "   Ou installe Node.js et relance ce script."
        ANON_KEY="placeholder_generate_with_jwt_io"
        SERVICE_ROLE_KEY="placeholder_generate_with_jwt_io"
    }

    if [ "$ANON_KEY" != "placeholder_generate_with_jwt_io" ]; then
        SERVICE_ROLE_KEY=$(node -e "
            const crypto = require('crypto');
            const key = '$JWT_SECRET';
            const header = { alg: 'HS256', typ: 'JWT' };
            const payload = {
                iss: 'supabase',
                ref: 'huntone',
                role: 'service_role',
                iat: Math.floor(Date.now() / 1000),
                exp: Math.floor(Date.now() / 1000) + 630720000
            };
            function btoa(s) { return Buffer.from(s).toString('base64url'); }
            const headerB64 = btoa(JSON.stringify(header));
            const payloadB64 = btoa(JSON.stringify(payload));
            const signature = crypto
                .createHmac('sha256', key)
                .update(headerB64 + '.' + payloadB64)
                .digest('base64url');
            console.log(headerB64 + '.' + payloadB64 + '.' + signature);
        ")
    fi

    export JWT_SECRET ANON_KEY SERVICE_ROLE_KEY
}

# ── Setup .env ──────────────────────────────────────────────────────────
setup_env() {
    local DB_PASSWORD
    DB_PASSWORD=$(openssl rand -base64 16)

    local DOMAIN="${1:-localhost}"

    cat > .env << EOF
# Huntone Environment
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=huntone

JWT_SECRET=${JWT_SECRET}
ANON_KEY=${ANON_KEY}
SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}

API_EXTERNAL_URL=https://${DOMAIN}
SUPABASE_PUBLIC_URL=https://${DOMAIN}

GOTRUE_SITE_URL=https://${DOMAIN}
GOTRUE_JWT_EXP=3600
GOTRUE_MAILER_AUTOCONFIRM=true

STORAGE_BACKEND=file
FILE_SIZE_LIMIT=52428800

STUDIO_PORT=3000
STUDIO_DEFAULT_ORGANIZATION=Huntone
STUDIO_DEFAULT_PROJECT=Huntone
EOF

    echo "✅ .env créé"
}

# ── Main ────────────────────────────────────────────────────────────────
main() {
    generate_jwt_keys
    setup_env "${1:-}"

    echo ""
    echo "🚀 Démarrage des conteneurs..."
    docker compose up -d

    echo ""
    echo "⏳ Attente du démarrage de PostgreSQL..."
    sleep 5

    echo "📦 Initialisation du bucket de stockage..."
    docker compose exec -T db psql -U postgres -d huntone -f /docker-entrypoint-initdb.d/../supabase/seed.sql 2>/dev/null || {
        echo "⚠️  Seed non appliqué automatiquement. Exécute manuellement :"
        echo "   docker compose exec db psql -U postgres -d huntone -f /docker-entrypoint-initdb.d/../supabase/seed.sql"
    }

    echo ""
    echo "✅ Huntone backend déployé !"
    echo ""
    echo "📋 Informations de connexion iOS :"
    echo "   Supabase URL:    http(s)://$(docker compose port kong 8000 2>/dev/null || echo 'VOTRE_VPS'):8000"
    echo "   Anon Key:        ${ANON_KEY}"
    echo ""
    echo "🔧 Studio Admin :"
    echo "   URL:             http://$(docker compose port studio 3000 2>/dev/null || echo 'VOTRE_VPS'):3000"
    echo "   Service Key:     ${SERVICE_ROLE_KEY}"
    echo ""
    echo "📱 Mettre à jour SupabaseClient.swift avec ces valeurs."
}

main "$@"
