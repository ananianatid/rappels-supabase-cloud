# Rappels — Supabase Self-Hosting

Stack Docker pour auto-héberger Supabase sur un VPS, utilisé par l'application Rappels pour la synchronisation cloud.

## Architecture

```
┌────────────────────────────────────────────┐
│  Kong (API Gateway — port 8000)            │
│  ┌──────┐ ┌──────┐ ┌────────┐ ┌────────┐  │
│  │ Auth │ │ REST │ │Realtime│ │Storage │  │
│  │GoTrue│ │PgREST│ │Server  │ │  API   │  │
│  └──┬───┘ └──┬───┘ └───┬────┘ └───┬────┘  │
│     └────────┼──────────┼──────────┘        │
│              ▼          ▼                   │
│       ┌──────────────────────┐              │
│       │  PostgreSQL 15       │              │
│       │  + Supabase Extensions│              │
│       └──────────────────────┘              │
└────────────────────────────────────────────┘
```

## Prérequis

- Docker + Docker Compose (v2+)
- Un VPS (minimum 2GB RAM, 20GB disque)
- Un domaine (optionnel, sinon accès par IP)

## Installation rapide

```bash
# 1. Cloner ce dépôt sur le VPS
git clone <repo-url> rappels-supabase
cd rappels-supabase

# 2. Générer les clés secrètes
openssl rand -base64 64 > jwt_secret.txt
openssl rand -base64 32 > anon_key.txt
openssl rand -base64 64 > service_key.txt

# 3. Configurer l'environnement
cp .env.example .env
# Éditer .env avec les valeurs générées

# 4. Démarrer la stack
docker compose up -d

# 5. Vérifier que tout tourne
docker compose ps
```

## Configuration

### Variables d'environnement (`.env`)

| Variable | Description |
|----------|-------------|
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL |
| `JWT_SECRET` | Clé JWT (min 64 chars base64) |
| `API_EXTERNAL_URL` | URL publique (domaine ou IP) |
| `ANON_KEY` | Clé publique visible côté client |
| `SERVICE_KEY` | Clé privée pour opérations admin |
| `MAILER_AUTOCONFIRM` | `true` = pas de confirmation email |

### Génération des clés

```bash
# JWT Secret
openssl rand -base64 64
# → copier dans JWT_SECRET

# Anon Key (clé publique)
openssl rand -base64 32
# → copier dans ANON_KEY

# Service Key
openssl rand -base64 64
# → copier dans SERVICE_KEY
```

## Utilisation

### API Endpoints (via Kong)

| Service | URL |
|---------|-----|
| REST API | `http://<vps>:8000/rest/v1/` |
| Auth | `http://<vps>:8000/auth/v1/` |
| Realtime | `ws://<vps>:8000/realtime/v1/` |
| Storage | `http://<vps>:8000/storage/v1/` |

### Dans l'app Rappels

Configurer `.env` du projet React :

```env
EXPO_PUBLIC_SUPABASE_URL=http://<vps-ip>:8000
EXPO_PUBLIC_SUPABASE_ANON_KEY=<votre-anon-key>
```

> ⚠️ **Sécurité** : Si vous utilisez HTTP (pas HTTPS), définissez `detectSessionInUrl: false` (déjà fait dans `client.ts`).

## HTTPS avec Caddy (recommandé)

Ajouter ce service dans `docker-compose.yml` :

```yaml
caddy:
  image: caddy:2
  container_name: rappels-caddy
  restart: unless-stopped
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./Caddyfile:/etc/caddy/Caddyfile
    - caddy-data:/data
  depends_on:
    - kong

volumes:
  caddy-data:
```

Et un `Caddyfile` :

```caddyfile
rappels.example.com {
    reverse_proxy kong:8000
}
```

## Maintenance

```bash
# Logs
docker compose logs -f

# Redémarrer un service
docker compose restart auth

# Mise à jour des images
docker compose pull
docker compose up -d

# Sauvegarde BDD
docker exec rappels-db pg_dump -U postgres > backup.sql

# Restauration
cat backup.sql | docker exec -i rappels-db psql -U postgres
```

## Base de données

Le schéma est initialisé automatiquement via `volumes/db/init.sql`. Il crée :

- `lists` — listes de rappels
- `reminders` — rappels individuels
- `subtasks` — sous-tâches
- `tags` / `reminder_tags` — tags (many-to-many)
- RLS policies — isolation par utilisateur
- Realtime — changements en temps réel

Pour appliquer des migrations supplémentaires :

```bash
# Copier un script SQL dans le volume
cp ma_migration.sql volumes/db/

# L'exécuter sur la base en cours
docker exec -i rappels-db psql -U postgres < volumes/db/ma_migration.sql
```
