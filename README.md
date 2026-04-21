# 🎯 Real Estate App - Docker Setup (EC2 + EBS)

**Status**: ✅ Complete & Ready for EC2 Production  
**Setup Type**: Image-only, Unified Docker Compose  
**Deployment Target**: AWS EC2 with EBS Volumes  
**Domain**: test.plotchoice.com  
**Last Updated**: April 2026

---

## 🚀 Quick Start

### For EC2 Production Deployment

⚠️ **IMPORTANT: Mount EBS volumes FIRST**
```bash
# Step 1: MANDATORY - Mount EBS volumes (interactive)
sudo bash scripts/setup-ebs.sh

# Step 2: Then run automated setup
sudo bash scripts/setup-all.sh test.plotchoice.com admin@example.com

# Done! Now proceed to DEPLOYMENT_GUIDE.md for remaining steps
```

**What happens:**
1. **setup-ebs.sh** - Mounts your 2 EBS volumes with persistent fstab config (5 min) ⬅️ **DO THIS FIRST**
2. **setup-all.sh** - Installs Docker, docker-compose, Certbot, SSL (5-10 min)
3. **DEPLOYMENT_GUIDE.md** - Remaining deployment steps (Steps 5+)

**Option 2: Manual Setup (Step-by-step)**
1. Read [SETUP-SCRIPTS.md](./SETUP-SCRIPTS.md) for detailed instructions
2. Follow manual steps or use individual scripts:
   - `scripts/setup-ebs.sh` - Mount EBS volumes (⚠️ DO FIRST)
   - `scripts/setup-docker.sh` - Install Docker only
   - `scripts/setup-certbot.sh` - Certbot and SSL only

**Option 3: Complete Deployment Guide**
1. Read [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Full step-by-step guide (70 min)
2. Includes all setup scripts, SSL certificates, Docker configuration, validation, and deployment

### Before You Start
⚠️ **Requires**:
- AWS EC2 instance running (t3.medium or larger)
- **2 EBS volumes ATTACHED to EC2 instance** (20GB for postgres, 5GB for certs)
  - NOT yet mounted - `setup-ebs.sh` will do this
  - You'll need to identify device names (e.g., /dev/nvme1n1)
- DNS A record pointing to EC2 IP
- SSH access to EC2 instance
- Domain name ready (test.plotchoice.com)

---

## 📚 Documentation Overview

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **README.md** | Quick reference & architecture | Now - overview only |
| **SETUP-SCRIPTS.md** | Automated & manual Docker/Certbot setup | 📌 Start here for server setup |
| **DEPLOYMENT_GUIDE.md** | Complete EC2 deployment (EBS → SSL → Docker → validation → deploy) | Alternative complete guide (70 min) |

---

## 🎨 What You Get

### ✅ Production-Ready Docker Setup
- **Single docker-compose.yml** - All services in one file (118 lines, clean & minimal)
- **Image-only approach** - Pre-built images, no building in compose
- **EBS volume mounting** - Persistent data storage (`/mnt/ebs/postgres`, `/mnt/ebs/certs`)
- **Simplified configuration** - Direct environment variables (no Docker Secrets)

### ✅ EC2 & EBS Ready
- **PostgreSQL on EBS** - Data persistence at `/mnt/ebs/postgres`
- **SSL certs on EBS** - Certificates stored at `/mnt/ebs/certs` (from Certbot on EC2)
- **fstab mounting** - Persistent mounts surviving EC2 reboots
- **optimized for AWS** - No local building, pure image-based deployment

### ✅ Security
- **HTTPS only** - HTTP redirects to HTTPS (test.plotchoice.com)
- **SSL via Certbot** - Managed on EC2 (not in container)
- **Auto-renewal** - EC2 certbot auto-renewal configured
- **Security headers** - HSTS, CSP, X-Frame-Options
- **Non-root containers** - Reduced privileged access

### ✅ Nginx Reverse Proxy
- **TLS termination** - Handles SSL/TLS
- **Rate limiting** - Prevent API abuse
- **Compression** - Smaller responses
- **Static caching** - Fast asset delivery
- **Security headers** - Best practices enforced

### ✅ Optimized Services
- **Backend (Express.js)** - TypeScript, Node.js 20-slim
- **Frontend (Next.js)** - Standalone mode, optimized for production
- **PostgreSQL 16** - Latest stable release on Alpine
- **Nginx 1.25** - Latest stable, Alpine-based

### ✅ Complete Documentation
- **SETUP-SCRIPTS.md** - Automated & manual setup (EBS mounting, Docker, Certbot, Secrets)
- **DEPLOYMENT_GUIDE.md** - Complete EC2 deployment guide (70 min total)
- **scripts/setup-ebs.sh** - Mount EBS volumes with persistent fstab (⚠️ RUN FIRST)
- **scripts/setup-all.sh** - One-command Docker + Certbot setup (runs after EBS mounting)
- **scripts/setup-secrets.sh** - Generate secure passwords and API keys
- **scripts/setup-docker.sh** - Docker-only installation with auto-start
- **scripts/setup-certbot.sh** - Certbot & SSL certificate setup with auto-renewal
- **.env.production.example** - Environment template with all required variables
- **Troubleshooting guides** - Common issues and solutions

---

## 📊 System Architecture

```
Internet Users (HTTPS)
        │
        ▼
    ┌──────────────────┐
    │  Nginx 1.25      │  ◄─ TLS Termination
    │  (Port 80/443)   │    SSL from /mnt/ebs/certs
    │  (Alpine)        │
    └────────┬─────────┘
             │
       ┌─────┴──────────┬──────────────┐
       │                │              │
    ┌──▼──┐          ┌──▼──┐       ┌──▼───┐
    │HTTP │          │ API │       │Static│
    │ →   │          │Routes        │Cache │
    │HTTPS│          │(WS)  │       │      │
    └─────┘          └──┬───┘       └──────┘
                        │
              ┌─────────┴─────────┐
              │                   │
          ┌───▼────┐          ┌───▼────┐
          │Backend │          │Frontend│
          │Express │          │Next.js │
          │:5000   │          │:3000   │
          └───┬────┘          └────────┘
              │
              ▼
        ┌──────────────────┐
        │ PostgreSQL 16    │  ◄─ Data on EBS
        │ Port 5432        │    /mnt/ebs/postgres
        │ (Alpine)         │
        └──────────────────┘

EBS Volumes:
- postgres (20GB): /mnt/ebs/postgres ◄─ Database data
- certs (5GB):     /mnt/ebs/certs    ◄─ SSL certificates

Networks:
- Frontend Net: Nginx ↔ Frontend
- Backend Net: Backend ↔ PostgreSQL (internal only)
```

---

## 📁 Folder Structure (Current)

```
docker-project/
├── README.md                           ◄─ Overview
├── EC2_SETUP.md                        ◄─ EC2 + EBS setup guide
├── DEPLOYMENT_CHECKLIST.md             ◄─ Deployment validation
│
├── docker-compose.yml                  ◄─ Main config (118 lines, image-only)
├── .env                                ◄─ Base env variables
├── .env.example                        ◄─ Template for reference
├── .env.production                     ◄─ EC2 production config
│
└── nginx/                              ◄─ Nginx configuration
    ├── nginx.conf                      ◄─ Main Nginx config
    └── conf.d/
        └── default.conf                ◄─ HTTPS/SSL/routing (test.plotchoice.com)

Source Dockerfiles (NOT in docker-project, stay in source repos):
├── ../RE-Backend/Dockerfile            ◄─ Backend (3-stage, 54 lines)
└── ../RE-FrontEnd/Dockerfile           ◄─ Frontend (3-stage, 47 lines)
```

**Key differences from old setup**:
- ✅ Single `docker-compose.yml` (was 8 files)
- ✅ No `dockerfiles/` folder (use source Dockerfiles directly)
- ✅ No `scripts/`, `backups/`, `secrets/`, `prometheus/` folders (cleaned up)
- ✅ Dockerfiles stay in source directories (RE-Backend, RE-FrontEnd)
- ✅ Only essential config files included

---

## 🔧 Key Features

### Containerization
- ✅ Image-only Docker Compose (pre-built images)
- ✅ Multi-stage builds for production
- ✅ Alpine Linux for minimal images
- ✅ Non-root users for security

### EBS Volume Management
- ✅ PostgreSQL data on `/mnt/ebs/postgres`
- ✅ SSL certs on `/mnt/ebs/certs`
- ✅ Permanent mounting via `/etc/fstab`
- ✅ Survives EC2 reboots

### Database
- ✅ PostgreSQL 16-alpine
- ✅ Data persists on EBS volumes
- ✅ Prisma ORM integration
- ✅ Ready for migrations

### Backend
- ✅ Express.js with TypeScript
- ✅ Node.js 20 (slim image)
- ✅ Health check endpoints
- ✅ Graceful shutdown

### Frontend
- ✅ Next.js 14+ with App Router
- ✅ Standalone mode
- ✅ Static asset optimization
- ✅ SEO-friendly

### Security
- ✅ HTTPS only (HTTP → HTTPS)
- ✅ Let's Encrypt SSL (Certbot on EC2)
- ✅ Auto-renewal via EC2 cron
- ✅ Security headers (HSTS, CSP, X-Frame-Options)
- ✅ Non-root containers
- ✅ Rate limiting (Nginx)

### Networking
- ✅ Nginx reverse proxy
- ✅ TLS termination
- ✅ HTTP/2 support
- ✅ Backend network isolated
- ✅ Frontend network public

### Reliability
- ✅ Automatic container restarts
- ✅ Health checks with retries
- ✅ Memory/CPU limits enforced
- ✅ Graceful error handling

---

## 🚀 Getting Started

### Prerequisites
```bash
# On EC2 instance:
- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM minimum (8GB recommended for production)
- 50GB disk space
- EBS volumes attached and formatted
- Certbot installed on EC2 (apt install certbot)
```

### Installation (4 steps)

**Step 1: Prepare EBS Volumes**
```bash
# SSH into EC2
ssh -i your-key.pem ec2-user@your-ec2-ip

# Format EBS volumes (if new)
sudo mkfs -t ext4 /dev/nvme1n1  # postgres
sudo mkfs -t ext4 /dev/nvme2n1  # certs

# Get UUIDs
sudo blkid

# Add to /etc/fstab (see EC2_SETUP.md for details)
sudo nano /etc/fstab
# Add:
# UUID=xxx  /mnt/ebs/postgres  ext4  defaults,nofail  0  2
# UUID=yyy  /mnt/ebs/certs     ext4  defaults,nofail  0  2

# Mount
sudo mount -a
```

**Step 2: Generate SSL Certificate**
```bash
sudo certbot certonly --standalone \
  -d test.plotchoice.com \
  -d www.test.plotchoice.com \
  --email admin@test.plotchoice.com

# Copy to EBS
sudo cp -r /etc/letsencrypt/live/test.plotchoice.com /mnt/ebs/certs/live/
sudo chown -R nobody:nobody /mnt/ebs/certs
```

**Step 3: Configure Environment**
```bash
# Clone repo and navigate to docker-project
cd docker-project

# Copy and edit environment file
cp .env.example .env.production

# Edit with your values:
nano .env.production
# Update:
# - POSTGRES_PASSWORD (change from "changeme")
# - JWT_ACCESS_SECRET
# - JWT_REFRESH_SECRET
# - AWS credentials (if using S3)
# - RESEND_API_KEY (if using email)
```

**Step 4: Deploy**
```bash
# Start services (pulling pre-built images)
docker-compose up -d

# Verify all running
docker-compose ps

# Check logs
docker-compose logs -f
```

### Verification
```bash
# All services running?
docker-compose ps

# Website accessible via HTTPS?
curl https://test.plotchoice.com

# API responding?
curl https://test.plotchoice.com/api/health

# SSL certificate valid?
echo | openssl s_client -servername test.plotchoice.com \
  -connect test.plotchoice.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

---

## 🔐 Environment Variables

Key variables to update in `.env.production`:

```bash
# Domain Configuration
DOMAIN=test.plotchoice.com
CERTBOT_EMAIL=admin@test.plotchoice.com

# Database (change password!)
POSTGRES_PASSWORD=your-secure-password-here
POSTGRES_USER=postgres
POSTGRES_DB=land_marketplace

# JWT Secrets (change these!)
JWT_ACCESS_SECRET=your-random-access-secret
JWT_REFRESH_SECRET=your-random-refresh-secret

# Email (Resend.dev)
RESEND_API_KEY=your-api-key
EMAIL_FROM=onboarding@resend.dev

# AWS S3 (optional)
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
S3_DOCS_BUCKET=your-bucket
S3_MEDIA_BUCKET=your-bucket
```

See `.env.example` for all available variables.

---

## 📖 Documentation Map

### For EC2 Deployment (First Time)
1. **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** - Complete guide with all steps
   - Follow from Step 1 through Step 5
   - Post-Deployment Validation section
   - Troubleshooting guide included
2. **[README.md](./README.md)** - This file - overview only
3. **[docker-compose.yml](./docker-compose.yml)** - Service definitions (reference)
4. **[.env.example](./.env.example)** - Environment variables (reference)

### For Daily Operations
See **Quick Commands Reference** in [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md#-quick-commands-reference)

### For Troubleshooting
See **Troubleshooting** section in [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md#-troubleshooting)

---

## 🔐 Security Checklist

- [ ] HTTPS enforced (HTTP redirects to HTTPS)
- [ ] SSL certificate valid (from Certbot on EC2)
- [ ] Certificate auto-renewal enabled on EC2
- [ ] All credentials updated in .env.production:
  - [ ] POSTGRES_PASSWORD changed
  - [ ] JWT_ACCESS_SECRET generated
  - [ ] JWT_REFRESH_SECRET generated
- [ ] AWS credentials (if using S3)
- [ ] API email configured (Resend/SendGrid)
- [ ] .env.production securely stored (not in git)
- [ ] EBS volumes mounted with correct permissions
- [ ] Certbot running on EC2 (systemctl status certbot-renew.timer)
- [ ] Regular security updates applied to EC2
- [ ] Monitoring/alerting configured

---

## 📊 Performance

### Image Sizes
- **Backend**: ~400MB (Node.js 20 slim, optimized)
- **Frontend**: ~150MB (Alpine base, Next.js standalone)
- **Nginx**: ~20MB (Alpine based)
- **PostgreSQL**: ~150MB (Alpine, 16-latest)
- **Total**: ~720MB all images

### Memory Usage (Idle)
- **Nginx**: 10-20MB
- **PostgreSQL**: 50-100MB
- **Backend**: 200-300MB
- **Frontend**: 100-150MB
- **Total**: ~400MB baseline

### Startup Time
- **Cold start** (first deployment): 30-45 seconds
- **Warm start** (restart): 10-15 seconds
- **Health checks**: 5-10 second window

### Storage
- **EBS postgres volume**: 20GB (adjustable)
- **EBS certs volume**: 5GB (for SSL certs)
- **Container layers**: ~720MB (images)

---

## 🔄 Update & Maintenance

### Regular Updates
```bash
# Update to latest image versions
docker-compose pull               # Download latest images
docker-compose up -d              # Restart with new images
docker-compose ps                 # Verify all running

# Check logs for errors
docker-compose logs -f
```

### Cleanup
```bash
# Remove unused Docker data
docker system prune -a            # Clean up unused images/containers
docker volume prune               # Clean up unused volumes
```

### Monitoring
```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs -f            # All services
docker-compose logs backend       # Single service
docker-compose logs --tail=100    # Last 100 lines

# Check resources
docker stats
```

### SSL Certificate Renewal
```bash
# Automatic (Certbot on EC2 runs daily)
sudo systemctl status certbot-renew.timer

# Manual renewal if needed
sudo certbot renew --force-renewal

# Verify certificates
sudo certbot certificates
```

### Database Maintenance
```bash
# Connect to database
docker-compose exec postgres psql -U postgres -d land_marketplace

# Backup
docker exec postgres pg_dump -U postgres -d land_marketplace > backup.sql

# Verify data
docker-compose exec postgres pg_isready -U postgres
```

---

## 🆘 Troubleshooting

### Services won't start
```bash
# Check logs
docker-compose logs

# Check what's wrong
docker-compose ps                 # Show status
df -h | grep /mnt/ebs            # Check EBS volumes mounted
mount | grep /mnt/ebs            # Verify mounts
```

### EBS volume not mounted
```bash
# List volumes
lsblk

# Check fstab
cat /etc/fstab | grep ebs

# Manually mount
sudo mount -a

# Check UUIDs match
sudo blkid                        # Compare with fstab values
```

### Database connection error
```bash
# Check Postgres logs
docker-compose logs postgres | tail -50

# Test connectivity
docker-compose exec postgres psql -U postgres -c "SELECT 1"

# Verify data on EBS
ls -la /mnt/ebs/postgres/base/
```

### SSL certificate issues
```bash
# Check certificate exists
ls -la /mnt/ebs/certs/live/test.plotchoice.com/

# Check Nginx can read it
docker exec nginx-server ls -la /etc/letsencrypt/live/test.plotchoice.com/

# Test HTTPS
curl -I https://test.plotchoice.com

# Certbot logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

### Port already in use
```bash
# Find what's using port 80/443
sudo netstat -tlnp | grep -E ':80|:443'

# Kill the process or use different port in compose
```

### For detailed troubleshooting, see [EC2_SETUP.md](./EC2_SETUP.md)

---

## 📞 Support Resources

- **Docker Docs**: https://docs.docker.com
- **Let's Encrypt**: https://letsencrypt.org
- **PostgreSQL**: https://www.postgresql.org/docs
- **Express.js**: https://expressjs.com
- **Next.js**: https://nextjs.org/docs

---

## 🎯 Next Steps

### Quick Setup (15 minutes total)

**Step 1: Mount EBS volumes (5 minutes)** ⚠️ MUST DO FIRST
```bash
sudo bash scripts/setup-ebs.sh
# Interactive script - you'll enter device names (e.g., /dev/nvme1n1, /dev/nvme2n1)
```

**Step 2: Install Docker & Certbot (5-10 minutes)**
```bash
sudo bash scripts/setup-all.sh your-domain.com your-email@example.com
```

**Step 3: Complete remaining deployment (DEPLOYMENT_GUIDE.md)**
1. Open [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) 
2. Follow Step 4 → Step 4.5 (Validation) → Step 5
3. Run dry-run commands in Step 4.5 before actual deployment
4. Complete Post-Deployment Validation section

### Available Guides
- **EBS Mounting (FIRST)**: [SETUP-SCRIPTS.md](./SETUP-SCRIPTS.md) - EBS Mounting section
- **Docker/Certbot Setup**: [SETUP-SCRIPTS.md](./SETUP-SCRIPTS.md) - Quick Start (Automated) or Manual Setup
- **Complete Deployment**: [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - All steps with validation

---

## ✅ Pre-Deployment Checklist

- [ ] EC2 instance running
- [ ] EBS volumes attached (postgres 20GB, certs 5GB)
- [ ] EBS volumes formatted (ext4)
- [ ] Volumes mounted to `/mnt/ebs/` with fstab
- [ ] SSL certificate generated by Certbot on EC2
- [ ] Certbot auto-renewal configured
- [ ] .env.production configured with credentials
- [ ] Pre-built images available (in registry)
- [ ] docker-compose.yml in docker-project/
- [ ] nginx/conf.d/default.conf points to test.plotchoice.com
- [ ] Ready to run `docker-compose up -d`

---

## 📝 Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0 | April 2026 | EC2 + EBS Optimization |
| | | - Removed Certbot container (managed on EC2) |
| | | - Switched to image-only approach (no build in compose) |
| | | - Configured EBS volume mounting with fstab |
| | | - Simplified to direct environment variables |
| | | - Cleaned up unnecessary files and folders |
| | | - Updated documentation for EC2 deployment |
| 1.0 | 2024 | Initial unified Docker setup |
| | | - Consolidated 8 separate docker-compose files |
| | | - Created optimized 3-stage Dockerfiles |
| | | - Added SSL/TLS with Let's Encrypt |
| | | - Comprehensive documentation |

---

## 📜 License

[Your License Here]

---

## 👥 Team

**Project**: Real Estate Application  
**Setup**: Unified Docker Configuration  
**Maintained by**: Development Team  
**Last Updated**: 2024

---

## 🎓 Learning Resources

- **Docker Multi-stage Builds**: https://docs.docker.com/build/building/multi-stage/
- **Docker Compose Networking**: https://docs.docker.com/compose/networking/
- **Let's Encrypt Certificate**: https://letsencrypt.org/getting-started/
- **Nginx Rate Limiting**: https://nginx.org/en/docs/http/ngx_http_limit_req_module.html
- **PostgreSQL Backup**: https://www.postgresql.org/docs/current/backup.html

---

## 🔗 Quick Links

- **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** ⭐ - **Start here** - Complete deployment guide
- **[docker-compose.yml](./docker-compose.yml)** - Service definitions
- **[.env.example](./.env.example)** - Environment variables template
- **[nginx/conf.d/default.conf](./nginx/conf.d/default.conf)** - Nginx configuration

---

**Ready to deploy? Open [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) and start from Step 1! 🚀**
