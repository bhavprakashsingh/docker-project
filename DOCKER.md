# Docker Runbook (Production)

Stacks: Postgres 16 + API (Express/Prisma) + Web (Next.js 16) + pgAdmin 4. Images are pulled from Docker Hub (`bhav760/*`).

## 1) Prepare `.env`
Copy `.env.example` → `.env` and fill everything:
- Images: `BACKEND_IMAGE`, `FRONTEND_IMAGE` (e.g., `bhav760/real-state-backend:1.0.0`, `bhav760/real-state-frontend:1.0.0`)
- Ports: `BACKEND_PORT`, `FRONTEND_PORT`, `PGADMIN_PORT` (bump host ports if 5000/3000/5050 are taken)
- DB: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `DATABASE_URL` (host must be `db`)
- Backend: `CLIENT_URL`, JWT secrets (`JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`), expiries, `OTP_EXPIRES_MINUTES`
- Frontend: `NEXT_PUBLIC_API_URL` (browser hits host port, e.g., `http://localhost:5001`), `INTERNAL_API_URL` (frontend server → backend inside compose, e.g., `http://backend:5000`)
- pgAdmin: `PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD`

## 2) What the Dockerfiles do (already baked into images)
- Backend (`RE-Backend/Dockerfile`):
  - Base `node:20-bookworm-slim` + installs `openssl` (fixes Prisma schema engine requirement)
  - `npm ci`, `prisma generate`, `tsc` (app + seed), prune dev deps
  - Entrypoint: `prisma migrate deploy || prisma db push` then `node dist/index.js`
- Frontend (`RE-FrontEnd/Dockerfile`):
  - Base `node:20-bookworm-slim`
  - `npm ci`, `next build` (uses Turbopack), prune dev deps
  - Uses `next.config.mjs` (no runtime TypeScript needed); runs `next start`
  - Landing page is dynamic to avoid build-time API timeouts
  - API client picks `INTERNAL_API_URL` on the server, `NEXT_PUBLIC_API_URL` in the browser

## 3) Build & push images (only when releasing a new version)
Backend:
```
cd RE-Backend
docker build -t bhav760/real-state-backend:1.0.0 -f Dockerfile .
docker push bhav760/real-state-backend:1.0.0
```
Frontend:
```
cd RE-FrontEnd
docker build -t bhav760/real-state-frontend:1.0.0 -f Dockerfile .
docker push bhav760/real-state-frontend:1.0.0
```
Update `.env` tags when you publish new versions.

## 4) Deploy with Compose (pull pre-built images)
```
docker compose pull
docker compose up -d
```
Service ports (host → container):
- API: `${BACKEND_PORT}:5000`
- Web: `${FRONTEND_PORT}:3000`
- pgAdmin: `${PGADMIN_PORT}:80`
- Postgres: internal only (no host port).

## 5) Access the app
- Web UI: `http://localhost:${FRONTEND_PORT}`
- API health: `http://localhost:${BACKEND_PORT}/health`
- pgAdmin (optional): `http://localhost:${PGADMIN_PORT}` → add a server with host `db`, port `5432`, user/pass from `.env`.

## 6) Seeding data (destructive)
```
docker compose run --rm backend node dist-seed/prisma/seed.js
```
Clears and repopulates DB; do not run on production data.

## 7) Operations
- Logs (follow): `docker compose logs -f backend` (or `frontend`, `db`, `pgadmin`)
- Stop: `docker compose down`
- Reset data: `docker compose down -v` (removes Postgres/pgAdmin volumes)
- Roll to new image: change tags in `.env`, then `docker compose pull && docker compose up -d`

## 8) Troubleshooting
- **Next.js build timed out on marketing page**: already mitigated (`dynamic = 'force-dynamic'`). If it reappears, ensure `NEXT_PUBLIC_API_URL` is reachable; set it to `http://backend:5000` for compose.
- **Module not found for UI components**: filenames are lowercase (`button.tsx`, `card.tsx`, `badge.tsx`, `input.tsx`). If you add new components, keep filenames and imports lowercase.
- **Prisma migration errors on start**: OpenSSL is baked into the image now; if errors persist, confirm `DATABASE_URL` points to `db` host and DB is healthy; check `docker compose logs backend` and `docker compose logs db`.
- **pgAdmin cannot connect**: use host `db` (not localhost), port `5432`, and credentials from `.env`.
- **Ports already in use**: change `BACKEND_PORT`/`FRONTEND_PORT`/`PGADMIN_PORT` in `.env` and rerun `docker compose up -d`.


docker compose exec db psql -U postgres -d realestate

docker compose up --scale backend=2 --scale frontend=2

## 9) Security
- Replace placeholder secrets before exposing publicly.
- Restrict pgAdmin to VPN/SSH tunnel or remove the service in `docker-compose.yml`.
- Terminate TLS in front of `frontend`/`backend` (Traefik/Caddy/nginx) for internet-facing deployments.
