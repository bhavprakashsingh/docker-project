# Production Docker Compose Examples

This document contains production-ready Docker Compose configurations that address the security and operational concerns identified in `PRODUCTION-IMPROVEMENTS.md`.

---

## 📁 File Structure

```
project/
├── docker-compose.yml              # Base configuration
├── docker-compose.prod.yml         # Production overrides
├── docker-compose.admin.yml        # Admin tools (separate)
├── .env.production                 # Production environment variables
├── secrets/                        # Docker secrets directory
│   ├── postgres_password.txt
│   ├── jwt_access_secret.txt
│   └── jwt_refresh_secret.txt
├── nginx/
│   ├── nginx.conf                  # Reverse proxy config
│   └── ssl/                        # TLS certificates
└── prometheus/
    └── prometheus.yml              # Monitoring config
```

---

## 🔐 docker-compose.prod.yml

**Production overrides with security hardening, resource limits, and monitoring.**

```yaml
# Production Docker Compose Override
# Deploy: docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

version: '3.8'

secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
  jwt_access_secret:
    file: ./secrets/jwt_access_secret.txt
  jwt_refresh_secret:
    file: ./secrets/jwt_refresh_secret.txt

networks:
  frontend-network:
    driver: bridge
  backend-network:
    driver: bridge
    internal: true
  db-network:
    driver: bridge
    internal: true
  monitoring:
    driver: bridge

services:
  db:
    secrets:
      - postgres_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    networks:
      - db-network
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
    command: >
      postgres
      -c max_connections=100
      -c shared_buffers=256MB
      -c effective_cache_size=1GB
      -c maintenance_work_mem=64MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=16MB
      -c default_statistics_target=100
      -c random_page_cost=1.1
      -c effective_io_concurrency=200
      -c work_mem=2621kB
      -c min_wal_size=1GB
      -c max_wal_size=4GB
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "db/{{.ID}}"
    security_opt:
      - no-new-privileges:true

  backend:
    secrets:
      - jwt_access_secret
      - jwt_refresh_secret
    environment:
      JWT_ACCESS_SECRET_FILE: /run/secrets/jwt_access_secret
      JWT_REFRESH_SECRET_FILE: /run/secrets/jwt_refresh_secret
    networks:
      - backend-network
      - db-network
    ports: []  # Remove direct port exposure
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
      rollback_config:
        parallelism: 1
        delay: 5s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "backend/{{.ID}}"
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL

  frontend:
    networks:
      - frontend-network
      - backend-network
    ports: []  # Remove direct port exposure
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "frontend/{{.ID}}"
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL

  # Reverse Proxy with TLS
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      frontend:
        condition: service_healthy
      backend:
        condition: service_healthy
    networks:
      - frontend-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "nginx/{{.ID}}"
    security_opt:
      - no-new-privileges:true

  # Monitoring
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
    networks:
      - monitoring
      - backend-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    security_opt:
      - no-new-privileges:true

  # Automated Backups
  backup:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data:ro
      - ./backups:/backups
    secrets:
      - postgres_password
    environment:
      PGHOST: db
      PGUSER: ${POSTGRES_USER}
      PGPASSWORD_FILE: /run/secrets/postgres_password
      PGDATABASE: ${POSTGRES_DB}
    command: >
      sh -c "
      while true; do
        PGPASSWORD=$$(cat /run/secrets/postgres_password) pg_dump -h db -U ${POSTGRES_USER} -Fc ${POSTGRES_DB} > /backups/backup_$$(date +%Y%m%d_%H%M%S).dump
        find /backups -name '*.dump' -mtime +7 -delete
        sleep 86400
      done
      "
    networks:
      - db-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 256M
    logging:
      driver: "json-file"
      options:
        max-size: "5m"
        max-file: "2"

volumes:
  prometheus_data:
    driver: local
    labels:
      com.example.description: "Prometheus metrics data"
  postgres_data:
    driver: local
    labels:
      com.example.description: "PostgreSQL production data"
      com.example.backup: "daily"
```

---

## 🔧 docker-compose.admin.yml

**Separate compose file for admin tools - only run when needed.**

```yaml
# Admin Tools Docker Compose
# Deploy: docker compose -f docker-compose.yml -f docker-compose.admin.yml up -d pgadmin
# Stop: docker compose -f docker-compose.yml -f docker-compose.admin.yml down

version: '3.8'

networks:
  db-network:
    external: true
    name: real-state_db-network

services:
  pgadmin:
    image: dpage/pgadmin4:8
    restart: "no"  # Don't auto-restart
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_DEFAULT_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_DEFAULT_PASSWORD}
      PGADMIN_CONFIG_SERVER_MODE: 'True'
      PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED: 'True'
    ports:
      - "127.0.0.1:${PGADMIN_PORT}:80"  # Bind to localhost only
    networks:
      - db-network
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "5m"
        max-file: "2"
    security_opt:
      - no-new-privileges:true

volumes:
  pgadmin_data:
    driver: local
```

---

## 🌐 nginx.conf

**Reverse proxy configuration with TLS, security headers, and rate limiting.**

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 20M;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=general_limit:10m rate=30r/s;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
    }

    # HTTPS Server
    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        # TLS Configuration
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Frontend (Next.js)
        location / {
            limit_req zone=general_limit burst=20 nodelay;
            proxy_pass http://frontend:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 90s;
        }

        # Backend API
        location /api {
            limit_req zone=api_limit burst=10 nodelay;
            proxy_pass http://backend:5000;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 90s;
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
```

---

## 📊 prometheus.yml

**Prometheus monitoring configuration.**

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'production'
    environment: 'prod'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'backend'
    static_configs:
      - targets: ['backend:5000']
    metrics_path: '/metrics'

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']
```

---

## 🔑 Setting Up Secrets

```bash
# Create secrets directory
mkdir -p secrets

# Generate strong secrets
openssl rand -base64 32 > secrets/postgres_password.txt
openssl rand -base64 64 > secrets/jwt_access_secret.txt
openssl rand -base64 64 > secrets/jwt_refresh_secret.txt

# Set proper permissions
chmod 600 secrets/*
```

---

## 🚀 Deployment Commands

### Initial Deployment
```bash
# 1. Set up secrets
./setup-secrets.sh

# 2. Pull latest images
docker compose -f docker-compose.yml -f docker-compose.prod.yml pull

# 3. Deploy
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 4. Verify health
docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
docker compose -f docker-compose.yml -f docker-compose.prod.yml logs -f
```

### Rolling Update
```bash
# Update images in .env
# Then:
docker compose -f docker-compose.yml -f docker-compose.prod.yml pull
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --no-deps --build backend
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --no-deps --build frontend
```

### Admin Tools (On-Demand)
```bash
# Start pgAdmin
docker compose -f docker-compose.yml -f docker-compose.admin.yml up -d pgadmin

# Access via SSH tunnel
ssh -L 5050:localhost:5050 user@production-server

# Stop when done
docker compose -f docker-compose.yml -f docker-compose.admin.yml down
```

---

## 📝 .env.production Template

```bash
# Postgres
POSTGRES_USER=postgres
POSTGRES_DB=realestate
# POSTGRES_PASSWORD is in secrets/postgres_password.txt

# Backend
BACKEND_PORT=5000
BACKEND_IMAGE=bhav760/real-state-backend:1.0.2
DATABASE_URL=postgresql://postgres@db:5432/realestate
CLIENT_URL=https://your-domain.com
# JWT secrets are in secrets/
JWT_ACCESS_EXPIRES=15m
JWT_REFRESH_EXPIRES=7d
OTP_EXPIRES_MINUTES=10

# Frontend
FRONTEND_PORT=3000
FRONTEND_IMAGE=bhav760/real-state-frontend:1.0.2
NEXT_PUBLIC_API_URL=https://your-domain.com/api
INTERNAL_API_URL=http://backend:5000

# Admin (only for docker-compose.admin.yml)
PGADMIN_PORT=5050
PGADMIN_DEFAULT_EMAIL=admin@your-domain.com
PGADMIN_DEFAULT_PASSWORD=change-me-strong-password
```

---

## ✅ Pre-Deployment Checklist

- [ ] Secrets generated and secured (600 permissions)
- [ ] TLS certificates obtained and configured
- [ ] Domain DNS configured
- [ ] Firewall rules configured (only 80/443 open)
- [ ] Backup storage configured
- [ ] Monitoring alerts configured
- [ ] Log aggregation configured
- [ ] Disaster recovery plan documented
- [ ] Security scan completed
- [ ] Load testing completed
- [ ] Rollback procedure tested

---

## 🔄 Backup & Restore

### Manual Backup
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml exec db \
  pg_dump -U postgres -Fc realestate > backup_$(date +%Y%m%d).dump
```

### Restore
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml exec -T db \
  pg_restore -U postgres -d realestate -c < backup_20260323.dump
```

### Verify Backups
```bash
# List backups
ls -lh backups/

# Test restore to temporary database
docker compose -f docker-compose.yml -f docker-compose.prod.yml exec db \
  createdb -U postgres test_restore
docker compose -f docker-compose.yml -f docker-compose.prod.yml exec -T db \
  pg_restore -U postgres -d test_restore < backups/backup_latest.dump