# SSL Certificate Management for Docker Nginx

This guide explains how SSL certificates are passed to the nginx Docker container and provides multiple options for certificate management.

## Current Implementation

In `docker-compose.prod.yml`, SSL certificates are mounted as a **read-only volume**:

```yaml
nginx:
  image: nginx:1.25-alpine
  volumes:
    - ./nginx/ssl:/etc/nginx/ssl:ro  # :ro = read-only mount
```

### How It Works

1. **Host Directory**: Certificates are stored in `./nginx/ssl/` on your host machine
2. **Container Mount**: This directory is mounted to `/etc/nginx/ssl/` inside the container
3. **Nginx Configuration**: Nginx reads certificates from `/etc/nginx/ssl/` (see `nginx/conf.d/default.conf`)

```nginx
ssl_certificate /etc/nginx/ssl/fullchain.pem;
ssl_certificate_key /etc/nginx/ssl/privkey.pem;
```

## Certificate Management Options

### Option 1: Volume Mount (Current - Recommended)

**Pros:**
- Simple and straightforward
- Easy to update certificates (just replace files and reload nginx)
- No need to rebuild images
- Works with Let's Encrypt auto-renewal

**Cons:**
- Certificates stored on host filesystem
- Need to manage file permissions

**Setup:**
```bash
# Place certificates in nginx/ssl/
cp /path/to/fullchain.pem ./nginx/ssl/
cp /path/to/privkey.pem ./nginx/ssl/
chmod 600 ./nginx/ssl/*.pem

# Reload nginx to pick up new certificates
docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

### Option 2: Docker Secrets (Most Secure)

**Pros:**
- Encrypted at rest and in transit
- Only accessible to authorized containers
- Better security for sensitive data

**Cons:**
- Requires Docker Swarm mode
- More complex setup

**Implementation:**

```yaml
# docker-compose.prod.yml (Swarm mode)
services:
  nginx:
    secrets:
      - ssl_certificate
      - ssl_certificate_key

secrets:
  ssl_certificate:
    file: ./nginx/ssl/fullchain.pem
  ssl_certificate_key:
    file: ./nginx/ssl/privkey.pem
```

**Nginx Configuration:**
```nginx
ssl_certificate /run/secrets/ssl_certificate;
ssl_certificate_key /run/secrets/ssl_certificate_key;
```

### Option 3: Let's Encrypt with Certbot

**Recommended for production with automatic renewal**

**Setup:**
```bash
# Install certbot on host
sudo apt-get install certbot

# Obtain certificate
sudo certbot certonly --standalone \
  -d yourdomain.com \
  -d www.yourdomain.com

# Copy to nginx/ssl/
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ./nginx/ssl/
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ./nginx/ssl/
sudo chmod 600 ./nginx/ssl/*.pem

# Setup auto-renewal (crontab)
0 0 * * * certbot renew --quiet && cp /etc/letsencrypt/live/yourdomain.com/*.pem /path/to/nginx/ssl/ && docker-compose -f /path/to/docker-compose.prod.yml exec nginx nginx -s reload
```

## Certificate Renewal

### Manual Renewal
```bash
# 1. Renew certificate
sudo certbot renew

# 2. Copy new certificates
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ./nginx/ssl/
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ./nginx/ssl/

# 3. Reload nginx (no downtime)
docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

### Automated Renewal Script

Create `scripts/renew-certs.sh`:
```bash
#!/bin/bash
set -e

certbot renew --quiet
cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ./nginx/ssl/
cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ./nginx/ssl/
chmod 600 ./nginx/ssl/*.pem
docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

## Security Best Practices

1. **File Permissions**
   ```bash
   chmod 600 ./nginx/ssl/*.pem
   ```

2. **Never Commit Certificates**
   ```bash
   echo "nginx/ssl/*.pem" >> .gitignore
   ```

3. **Monitor Expiration**
   ```bash
   openssl x509 -in ./nginx/ssl/fullchain.pem -noout -dates
   ```

## Troubleshooting

### Certificate Not Found
```bash
# Check files exist
ls -la ./nginx/ssl/

# Check nginx can read them
docker-compose -f docker-compose.prod.yml exec nginx ls -la /etc/nginx/ssl/
```

### Permission Denied
```bash
chmod 600 ./nginx/ssl/*.pem
```

### Certificate Expired
```bash
# Check expiration
openssl x509 -in ./nginx/ssl/fullchain.pem -noout -dates

# Renew
sudo certbot renew --force-renewal
```

## Summary

The current implementation uses **Volume Mount (Option 1)**, which is:
- ✅ Simple and effective
- ✅ Easy to update certificates
- ✅ Compatible with Let's Encrypt
- ✅ No image rebuilds needed

Certificates are passed to the container via a **read-only volume mount** from `./nginx/ssl/` on the host to `/etc/nginx/ssl/` in the container.