# Production Deployment Guide

This guide provides step-by-step instructions for deploying your Real Estate application to production using the production-ready Docker Compose configuration.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Configuration](#configuration)
4. [SSL Certificates](#ssl-certificates)
5. [Deployment](#deployment)
6. [Monitoring](#monitoring)
7. [Backup & Recovery](#backup--recovery)
8. [Maintenance](#maintenance)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

- Docker Engine 20.10+ and Docker Compose 2.0+
- Linux server (Ubuntu 20.04+ recommended)
- Domain name with DNS configured
- Minimum 4GB RAM, 2 CPU cores, 50GB storage
- Root or sudo access

## Initial Setup

### 1. Clone Repository

```bash
git clone <your-repo-url>
cd real-state
```

### 2. Generate Secrets

```bash
chmod +x scripts/setup-secrets.sh
./scripts/setup-secrets.sh
```

This creates secure random secrets in the `secrets/` directory.

### 3. Configure Environment

```bash
cp .env.production .env
nano .env
```

Update the following critical values:
- Domain names (replace `yourdomain.com`)
- Image tags (if using custom builds)
- Admin passwords
- Backup retention settings

## Configuration

### Network Configuration

The production setup uses three isolated networks:

- **frontend** (172.20.0.0/24) - Public-facing services
- **backend** (172.21.0.0/24) - Internal services (isolated)
- **monitoring** (172.22.0.0/24) - Monitoring stack (isolated)

### Resource Limits

Each service has defined resource limits:

| Service | CPU Limit | Memory Limit |
|---------|-----------|--------------|
| nginx | 0.5 | 256MB |
| backend | 1.0 | 1GB |
| frontend | 1.0 | 1GB |
| db | 2.0 | 2GB |
| prometheus | 0.5 | 512MB |
| grafana | 0.5 | 512MB |

Adjust these in `docker-compose.prod.yml` based on your server capacity.

## SSL Certificates

### Option 1: Let's Encrypt (Recommended)

```bash
# Install certbot
sudo apt-get update
sudo apt-get install certbot

# Obtain certificate
sudo certbot certonly --standalone \
  -d yourdomain.com \
  -d www.yourdomain.com

# Copy certificates
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ./nginx/ssl/
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ./nginx/ssl/
sudo chmod 600 ./nginx/ssl/*.pem
```

### Option 2: Self-Signed (Testing Only)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./nginx/ssl/privkey.pem \
  -out ./nginx/ssl/fullchain.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=yourdomain.com"
chmod 600 ./nginx/ssl/*.pem
```

### Update Nginx Configuration

Edit `nginx/conf.d/default.conf` and replace `yourdomain.com` with your actual domain.

## Deployment

### 1. Build Images (if needed)

```bash
# Backend
cd RE-Backend
docker build -t bhav760/real-state-backend:1.0.2 .

# Frontend
cd ../RE-FrontEnd
docker build -t bhav760/real-state-frontend:1.0.2 .
```

### 2. Deploy Production Stack

```bash
# Start production services
docker-compose -f docker-compose.prod.yml up -d

# Check service status
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs -f
```

### 3. Deploy Admin Tools (Optional)

```bash
# Start admin services (pgAdmin, Portainer)
docker-compose -f docker-compose.prod.yml -f docker-compose.admin.yml up -d
```

### 4. Verify Deployment

```bash
# Check all services are healthy
docker-compose -f docker-compose.prod.yml ps

# Test endpoints
curl -k https://yourdomain.com/health
curl -k https://yourdomain.com/api/health
```

## Monitoring

### Access Monitoring Tools

- **Prometheus**: https://yourdomain.com/prometheus (restricted to monitoring network)
- **Grafana**: https://yourdomain.com/grafana
  - Default credentials: admin / (from .env GRAFANA_ADMIN_PASSWORD)
- **Portainer**: https://localhost:9443 (if admin tools deployed)

### Configure Grafana

1. Login to Grafana
2. Add Prometheus data source: http://prometheus:9090
3. Import dashboards for:
   - Node metrics
   - PostgreSQL metrics
   - Application metrics

### Alert Configuration

Alerts are defined in `prometheus/alerts/`:
- `backend.yml` - Backend service alerts
- `database.yml` - Database alerts

Configure alert notifications in Prometheus or Grafana.

## Backup & Recovery

### Automated Backups

Backups run automatically via the backup service. Configure schedule in crontab:

```bash
# Run backup daily at 2 AM
0 2 * * * cd /path/to/real-state && docker-compose -f docker-compose.prod.yml run --rm backup
```

### Manual Backup

```bash
docker-compose -f docker-compose.prod.yml run --rm backup
```

Backups are stored in `./backups/` directory.

### Restore from Backup

```bash
# Make restore script executable
chmod +x scripts/restore.sh

# List available backups
ls -lh backups/

# Restore specific backup
docker-compose -f docker-compose.prod.yml run --rm \
  -v $(pwd)/scripts:/scripts \
  backup /scripts/restore.sh /backups/backup_YYYYMMDD_HHMMSS.sql.gz
```

## Maintenance

### Update Application

```bash
# Pull new images
docker-compose -f docker-compose.prod.yml pull

# Recreate containers with new images
docker-compose -f docker-compose.prod.yml up -d

# Remove old images
docker image prune -f
```

### Scale Services

```bash
# Scale backend to 3 replicas
docker-compose -f docker-compose.prod.yml up -d --scale backend=3

# Scale frontend to 3 replicas
docker-compose -f docker-compose.prod.yml up -d --scale frontend=3
```

### View Logs

```bash
# All services
docker-compose -f docker-compose.prod.yml logs -f

# Specific service
docker-compose -f docker-compose.prod.yml logs -f backend

# Last 100 lines
docker-compose -f docker-compose.prod.yml logs --tail=100 backend
```

### Database Maintenance

```bash
# Connect to database
docker-compose -f docker-compose.prod.yml exec db psql -U postgres -d realestate

# Vacuum database
docker-compose -f docker-compose.prod.yml exec db psql -U postgres -d realestate -c "VACUUM ANALYZE;"
```

## Troubleshooting

### Service Won't Start

```bash
# Check service logs
docker-compose -f docker-compose.prod.yml logs service-name

# Check service health
docker-compose -f docker-compose.prod.yml ps

# Restart specific service
docker-compose -f docker-compose.prod.yml restart service-name
```

### Database Connection Issues

```bash
# Check database is healthy
docker-compose -f docker-compose.prod.yml exec db pg_isready -U postgres

# Check database logs
docker-compose -f docker-compose.prod.yml logs db

# Verify connection from backend
docker-compose -f docker-compose.prod.yml exec backend nc -zv db 5432
```

### High Memory Usage

```bash
# Check resource usage
docker stats

# Adjust resource limits in docker-compose.prod.yml
# Then recreate services
docker-compose -f docker-compose.prod.yml up -d
```

### SSL Certificate Issues

```bash
# Verify certificate files exist
ls -l nginx/ssl/

# Check certificate expiration
openssl x509 -in nginx/ssl/fullchain.pem -noout -dates

# Test SSL configuration
openssl s_client -connect yourdomain.com:443
```

### Network Issues

```bash
# Check network connectivity
docker network ls
docker network inspect real-state_frontend
docker network inspect real-state_backend

# Test service connectivity
docker-compose -f docker-compose.prod.yml exec backend ping db
docker-compose -f docker-compose.prod.yml exec frontend ping backend
```

## Security Checklist

- [ ] All secrets generated and secured (600 permissions)
- [ ] SSL certificates installed and valid
- [ ] Domain name configured in nginx
- [ ] Firewall configured (ports 80, 443 only)
- [ ] Admin tools restricted or disabled
- [ ] Database password changed from default
- [ ] JWT secrets are strong and unique
- [ ] Backup retention configured
- [ ] Monitoring alerts configured
- [ ] Log rotation enabled
- [ ] Regular security updates scheduled

## Performance Optimization

### Database Tuning

The production configuration includes optimized PostgreSQL settings. For high-traffic sites, consider:

1. Increasing `shared_buffers` to 25% of RAM
2. Adjusting `max_connections` based on load
3. Enabling connection pooling (PgBouncer)
4. Setting up read replicas

### Caching

The nginx configuration includes:
- Static asset caching (1 year)
- API response caching (configurable)
- Gzip compression

Consider adding:
- Redis for session/data caching
- CDN for static assets

### Load Balancing

For high availability:
1. Deploy multiple instances across regions
2. Use external load balancer (AWS ALB, Cloudflare)
3. Configure health checks
4. Implement blue-green deployments

## Support

For issues or questions:
- Check logs: `docker-compose -f docker-compose.prod.yml logs`
- Review monitoring dashboards
- Consult PRODUCTION-IMPROVEMENTS.md for detailed explanations

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)