# 🚀 Complete Deployment Setup Guide

## 📋 Overview

This guide will help you set up your Real Estate application using the docker-compose.yml configuration. Based on your current setup, here's what you need to do.

---

## ✅ Current Status - Files Verified

Your `docker-project/` directory has all essential files:

```
✅ docker-compose.yml          - Service definitions (nginx, postgres, backend, frontend)
✅ .env                         - Base environment variables (needs updating for production)
✅ nginx/nginx.conf             - Main nginx configuration
✅ nginx/conf.d/default.conf    - SSL/HTTPS routing for test.plotchoice.com
✅ scripts/setup-all.sh         - Automated Docker + Certbot setup
✅ scripts/setup-ebs.sh         - EBS volume mounting (RUN FIRST)
✅ scripts/setup-secrets.sh     - Generate secure passwords
✅ scripts/setup-docker.sh      - Docker installation only
✅ scripts/setup-certbot.sh     - SSL certificate setup
✅ DEPLOYMENT_GUIDE.md          - Complete 70-minute deployment guide
✅ README.md                    - Quick reference
```

---

## 🎯 Deployment Path - Choose Your Approach

### Option 1: Quick Automated Setup (Recommended - 20 minutes)

**Best for**: First-time deployment, want to get running quickly

```bash
# Step 1: Mount EBS volumes (MUST DO FIRST - 5 min)
sudo bash scripts/setup-ebs.sh

# Step 2: Install Docker + Certbot + SSL (5-10 min)
sudo bash scripts/setup-all.sh test.plotchoice.com admin@example.com

# Step 3: Generate secrets locally (2 min)
bash scripts/setup-secrets.sh

# Step 4: Create .env.production with generated secrets (3 min)
# Copy secrets from setup-secrets.sh output into .env.production

# Step 5: Copy files to EC2 and deploy (5 min)
# See "File Transfer" section below
```

### Option 2: Manual Step-by-Step (70 minutes)

**Best for**: Learning the process, custom configuration needs

Follow the complete guide: [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)

---

## 🔧 Pre-Deployment Checklist

Before starting, ensure you have:

### Infrastructure Ready
- [ ] AWS EC2 instance running (t3.medium or larger recommended)
- [ ] 2 EBS volumes attached to EC2:
  - [ ] 20GB volume for PostgreSQL data
  - [ ] 5GB volume for SSL certificates
- [ ] DNS A record: `test.plotchoice.com` → Your EC2 IP address
- [ ] Security Groups configured:
  - [ ] Port 22 (SSH) - Your IP only
  - [ ] Port 80 (HTTP) - 0.0.0.0/0
  - [ ] Port 443 (HTTPS) - 0.0.0.0/0
- [ ] SSH key pair for EC2 access

### Local Machine Ready
- [ ] SSH access to EC2 configured
- [ ] Git repository cloned locally
- [ ] All files in `docker-project/` directory present

### Docker Images
Your docker-compose.yml references:
- Backend: `${BACKEND_IMAGE:-real-estate-backend:latest}`
- Frontend: `${FRONTEND_IMAGE:-real-estate-frontend:latest}`

**Action Required**: You need to either:
1. **Build images locally** and push to a registry (Docker Hub, AWS ECR, etc.)
2. **Build images on EC2** by modifying docker-compose.yml to use build context
3. **Use pre-built images** if already available in a registry

---

## 🔐 Step 1: Generate Secure Secrets (Local Machine)

**Time**: 5 minutes  
**Location**: Your local machine

```bash
# Navigate to docker-project directory
cd docker-project/

# Generate secure secrets
bash scripts/setup-secrets.sh

# Save output - you'll need these values!
```

**Output will look like**:
```
POSTGRES_PASSWORD=aB3xYz9mK2pQ5vN8wL1cD4eF6gH7
JWT_ACCESS_SECRET=x9kL2mN5pQ8vW1aB4cD7eF0gH3jK6
JWT_REFRESH_SECRET=j8mN2pQ5tU6vW9yZ1bC4dE7fG0hI3
ENCRYPTION_KEY=z7mN2pQ5tU6vW9yZ1bC4dE7fG0hI3j5
```

**Save these securely** - you'll need them in the next step!

---

## 📝 Step 2: Create .env.production (Local Machine)

**Time**: 5 minutes  
**Location**: Your local machine

Create a new file `.env.production` in the `docker-project/` directory:

```bash
# Create from template
cp .env .env.production

# Edit with your values
nano .env.production  # or use your preferred editor
```

**Update these critical values**:

```bash
# ============================================================================
# PRODUCTION ENVIRONMENT - test.plotchoice.com
# ============================================================================

# Core Application
NODE_ENV=production
APP_URL=https://test.plotchoice.com
CLIENT_URL=https://test.plotchoice.com

# Database - Use generated password from Step 1
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<PASTE_GENERATED_PASSWORD_HERE>
POSTGRES_DB=land_marketplace
DATABASE_URL=postgresql://postgres:<PASTE_SAME_PASSWORD>@postgres:5432/land_marketplace?schema=public

# JWT Secrets - Use generated secrets from Step 1
JWT_ACCESS_SECRET=<PASTE_GENERATED_JWT_ACCESS_SECRET>
JWT_REFRESH_SECRET=<PASTE_GENERATED_JWT_REFRESH_SECRET>
JWT_ACCESS_EXPIRES=15m
JWT_REFRESH_EXPIRES=7d

# Encryption - Use generated key from Step 1
ENCRYPTION_KEY=<PASTE_GENERATED_ENCRYPTION_KEY>

# Email Configuration (Get from https://resend.com)
RESEND_API_KEY=re_your_actual_api_key_from_resend
EMAIL_FROM=noreply@test.plotchoice.com
EMAIL_FROM_NAME=Real Estate Platform
ADMIN_EMAIL=admin@test.plotchoice.com
ADMIN_ALERT_EMAIL=alerts@test.plotchoice.com

# Frontend URLs
NEXT_PUBLIC_API_URL=https://test.plotchoice.com/api
NEXT_PUBLIC_SITE_URL=https://test.plotchoice.com
INTERNAL_API_URL=http://backend:5000

# Domain & SSL
DOMAIN=test.plotchoice.com
CERTBOT_EMAIL=admin@test.plotchoice.com

# Docker Images (update with your registry)
BACKEND_IMAGE=your-registry/real-estate-backend:latest
FRONTEND_IMAGE=your-registry/real-estate-frontend:latest

# AWS S3 (Optional - if using file uploads)
AWS_ACCESS_KEY_ID=your_aws_access_key_id
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
AWS_REGION=ap-south-1
S3_DOCS_BUCKET=your-docs-bucket-name
S3_MEDIA_BUCKET=your-media-bucket-name
CLOUDFRONT_URL=https://your-cloudfront-domain.cloudfront.net

# Misc
AGENT_LISTING_LIMIT=10
OTP_EXPIRES_MINUTES=10
```

**Protect this file**:
```bash
# Set secure permissions
chmod 600 .env.production

# Verify it's in .gitignore
echo ".env.production" >> .gitignore
```

---

## 🏗️ Step 3: Build or Prepare Docker Images

**Time**: 10-30 minutes (depending on approach)

### Option A: Build Images Locally & Push to Registry

```bash
# Build backend image
cd ../RE-Backend
docker build -t your-registry/real-estate-backend:latest .
docker push your-registry/real-estate-backend:latest

# Build frontend image
cd ../RE-FrontEnd
docker build -t your-registry/real-estate-frontend:latest \
  --build-arg NEXT_PUBLIC_API_URL=https://test.plotchoice.com/api \
  --build-arg NEXT_PUBLIC_SITE_URL=https://test.plotchoice.com \
  --build-arg INTERNAL_API_URL=http://backend:5000 \
  .
docker push your-registry/real-estate-frontend:latest
```

### Option B: Build on EC2 (Modify docker-compose.yml)

If you prefer to build on EC2, you'll need to modify `docker-compose.yml` to include build contexts. The current file is configured for pre-built images only.

---

## 📦 Step 4: Transfer Files to EC2

**Time**: 5 minutes  
**Location**: Your local machine

### Files to Transfer

```bash
# From your local machine, transfer these files:
cd docker-project/

# Create directory on EC2
ssh -i your-key.pem ec2-user@your-ec2-ip "mkdir -p ~/real-estate/docker-project/nginx/conf.d"

# Transfer essential files
scp -i your-key.pem docker-compose.yml ec2-user@your-ec2-ip:~/real-estate/docker-project/
scp -i your-key.pem .env.production ec2-user@your-ec2-ip:~/real-estate/docker-project/
scp -i your-key.pem nginx/nginx.conf ec2-user@your-ec2-ip:~/real-estate/docker-project/nginx/
scp -i your-key.pem nginx/conf.d/default.conf ec2-user@your-ec2-ip:~/real-estate/docker-project/nginx/conf.d/

# Transfer reference files (optional but recommended)
scp -i your-key.pem README.md ec2-user@your-ec2-ip:~/real-estate/docker-project/
scp -i your-key.pem DEPLOYMENT_GUIDE.md ec2-user@your-ec2-ip:~/real-estate/docker-project/
```

**Verify on EC2**:
```bash
ssh -i your-key.pem ec2-user@your-ec2-ip
cd ~/real-estate/docker-project
ls -la
# Should show: docker-compose.yml, .env.production, nginx/, README.md
```

---

## 🖥️ Step 5: Setup EC2 Server

**Time**: 15 minutes  
**Location**: EC2 instance (SSH)

### 5.1: Mount EBS Volumes (CRITICAL - DO FIRST)

```bash
# SSH into EC2
ssh -i your-key.pem ec2-user@your-ec2-ip

# Run EBS setup script (interactive)
sudo bash ~/real-estate/docker-project/scripts/setup-ebs.sh

# Or if scripts not transferred, do manually:
# See DEPLOYMENT_GUIDE.md Step 1 for manual instructions
```

**What this does**:
- Identifies your EBS volumes
- Formats them (if new)
- Mounts to `/mnt/ebs/postgres` and `/mnt/ebs/certs`
- Adds to `/etc/fstab` for persistence
- Sets correct permissions

### 5.2: Install Docker & Certbot

```bash
# Automated installation
sudo bash ~/real-estate/docker-project/scripts/setup-all.sh test.plotchoice.com admin@test.plotchoice.com

# Or manual installation - see DEPLOYMENT_GUIDE.md Steps 2-3
```

**What this does**:
- Installs Docker and Docker Compose
- Installs Certbot
- Generates SSL certificate for test.plotchoice.com
- Copies certificate to EBS volume
- Sets up auto-renewal

---

## 🚀 Step 6: Deploy Application

**Time**: 5 minutes  
**Location**: EC2 instance

```bash
# Navigate to project directory
cd ~/real-estate/docker-project

# Verify configuration
docker compose config

# Pull images (if using registry)
docker compose pull

# Start services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

**Expected output**:
```
NAME                IMAGE                              STATUS
nginx-proxy         nginx:1.25-alpine                  Up (healthy)
postgres-db         postgres:16-alpine                 Up (healthy)
backend-api         real-estate-backend:latest         Up (healthy)
frontend-app        real-estate-frontend:latest        Up (healthy)
```

---

## ✅ Step 7: Verify Deployment

**Time**: 10 minutes

### 7.1: Check All Services Running

```bash
docker compose ps
# All should show "Up" status
```

### 7.2: Test HTTPS Access

```bash
# From EC2 or your local machine
curl -I https://test.plotchoice.com
# Should return: HTTP/2 200

# Test API
curl https://test.plotchoice.com/api/health
# Should return: {"status":"ok"} or similar
```

### 7.3: Check SSL Certificate

```bash
echo | openssl s_client -servername test.plotchoice.com \
  -connect test.plotchoice.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

### 7.4: Verify Database

```bash
docker compose exec postgres psql -U postgres -d land_marketplace -c "SELECT 1;"
# Should return: 1
```

### 7.5: Check Logs for Errors

```bash
docker compose logs --tail=50
# Look for any ERROR or FATAL messages
```

---

## 🔍 Troubleshooting

### Services Won't Start

```bash
# Check logs
docker compose logs

# Check EBS volumes
df -h | grep /mnt/ebs

# Verify .env.production
cat .env.production | grep POSTGRES_PASSWORD
```

### SSL Certificate Issues

```bash
# Check certificate exists
ls -la /mnt/ebs/certs/live/test.plotchoice.com/

# Check Nginx can access it
docker compose exec nginx ls -la /etc/letsencrypt/live/test.plotchoice.com/

# Regenerate if needed
sudo certbot certonly --standalone -d test.plotchoice.com
```

### Database Connection Errors

```bash
# Check Postgres is running
docker compose ps postgres

# Check logs
docker compose logs postgres

# Verify password in .env.production matches
docker compose exec postgres psql -U postgres -d land_marketplace
```

### Port Already in Use

```bash
# Check what's using ports 80/443
sudo netstat -tlnp | grep -E ':80|:443'

# Stop conflicting service
sudo systemctl stop httpd  # or apache2, nginx, etc.
```

---

## 📊 Post-Deployment Tasks

### Daily Operations

```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f

# Restart a service
docker compose restart backend

# Update to latest images
docker compose pull
docker compose up -d
```

### Weekly Maintenance

```bash
# Check disk usage
df -h
docker system df

# Clean up unused resources
docker system prune -a

# Backup database
docker compose exec postgres pg_dump -U postgres land_marketplace > backup_$(date +%Y%m%d).sql
```

### Monthly Tasks

```bash
# Update system packages
sudo yum update -y  # Amazon Linux
# or: sudo apt update && sudo apt upgrade -y  # Ubuntu

# Verify SSL auto-renewal
sudo systemctl status certbot-renew.timer

# Review logs for issues
docker compose logs --since 30d | grep -i error
```

---

## 🔐 Security Checklist

- [ ] `.env.production` has secure passwords (not "changeme")
- [ ] `.env.production` permissions set to 600
- [ ] SSL certificate valid and auto-renewing
- [ ] HTTPS enforced (HTTP redirects to HTTPS)
- [ ] EC2 Security Groups properly configured
- [ ] SSH key-based authentication only (no password auth)
- [ ] Regular system updates scheduled
- [ ] Database backups configured
- [ ] Monitoring/alerting set up

---

## 📞 Need Help?

### Documentation
- **Complete Guide**: [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- **Quick Reference**: [README.md](./README.md)
- **Scripts Guide**: [SETUP-SCRIPTS.md](./SETUP-SCRIPTS.md)

### Common Issues
See the Troubleshooting section in [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md#-troubleshooting)

### Quick Commands

```bash
# View all services
docker compose ps

# Restart everything
docker compose restart

# Stop everything
docker compose down

# Start everything
docker compose up -d

# View logs
docker compose logs -f [service-name]

# Execute command in container
docker compose exec [service-name] [command]
```

---

## ✨ Success Indicators

Your deployment is successful when:

✅ All 4 services show "Up (healthy)" status  
✅ Website loads at https://test.plotchoice.com  
✅ API responds at https://test.plotchoice.com/api/health  
✅ SSL certificate is valid (green padlock in browser)  
✅ No errors in `docker compose logs`  
✅ Database accepts connections  
✅ EBS volumes mounted and persisting data  

---

**🎉 Congratulations! Your Real Estate application is now deployed!**

For ongoing maintenance and operations, refer to the [README.md](./README.md) Quick Commands section.