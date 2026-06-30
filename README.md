# Rappels — Supabase Self-Hosting

Stack Docker pour auto-héberger Supabase sur un VPS.

## Stack
- **PostgreSQL 15** avec extensions Supabase
- **Kong** (API Gateway, port 8000)
- **GoTrue** (Auth)
- **PostgREST** (REST API)
- **Realtime** (WebSocket)
- **Storage** (fichiers)

## Démarrage rapide

```bash
cp .env.example .env
# Éditer .env avec les clés générées
docker compose up -d
```

## API Endpoints
| Service | URL |
|---------|-----|
| REST | `http://<vps>:8000/rest/v1/` |
| Auth | `http://<vps>:8000/auth/v1/` |
| Realtime | `ws://<vps>:8000/realtime/v1/` |
