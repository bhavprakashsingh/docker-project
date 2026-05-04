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


### AWS S3 & CloudFront Configuration
To configure the required AWS S3 buckets and CloudFront distribution, refer to **Part 4: S3, CloudFront & IAM Setup** in `AWS_DEPLOYMENT_STEPS.md`. You will need to create the buckets, IAM user, and distribution to get the S3 and CloudFront environment variables.

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
BACKEND_IMAGE=bhav760/real-estate-backend:latest
FRONTEND_IMAGE=bhav760/real-estate-frontend:latest

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

## 🏗️ Step 3: Build Docker Images using Docker Compose

**Time**: 10-30 minutes (depending on your machine)

Your `docker-compose.yml` is already configured with build contexts for both backend and frontend. You can easily build the images locally and push them to your registry (`bhav760`).

```bash
# 1. Login to Docker Hub (if not already logged in)
docker login

# 2. Build the images using docker-compose
# Ensure your .env.production file has BACKEND_IMAGE=bhav760/real-estate-backend:latest
# and FRONTEND_IMAGE=bhav760/real-estate-frontend:latest
cd docker-project/
docker compose --env-file .env.production build

# 3. Push the built images to your registry
docker compose --env-file .env.production push
```

*Note: The frontend build step will automatically use the `NEXT_PUBLIC_*` variables from your `.env.production` file so they are correctly baked into the static bundle.*

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
docker compose --env-file .env.production config

# Pull images (if using registry)
docker compose --env-file .env.production pull

# Start services
docker compose --env-file .env.production up -d

# Check status
docker compose --env-file .env.production ps

# View logs
docker compose --env-file .env.production logs -f
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
docker compose --env-file .env.production ps
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
docker compose --env-file .env.production exec postgres psql -U postgres -d land_marketplace -c "SELECT 1;"
# Should return: 1
```

### 7.5: Check Logs for Errors

```bash
docker compose --env-file .env.production logs --tail=50
# Look for any ERROR or FATAL messages
```

---

## 🔍 Troubleshooting

### Services Won't Start

```bash
# Check logs
docker compose --env-file .env.production logs

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
docker compose --env-file .env.production exec nginx ls -la /etc/letsencrypt/live/test.plotchoice.com/

# Regenerate if needed
sudo certbot certonly --standalone -d test.plotchoice.com
```

### Database Connection Errors

```bash
# Check Postgres is running
docker compose --env-file .env.production ps postgres

# Check logs
docker compose --env-file .env.production logs postgres

# Verify password in .env.production matches
docker compose --env-file .env.production exec postgres psql -U postgres -d land_marketplace
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
docker compose --env-file .env.production ps

# View logs
docker compose --env-file .env.production logs -f

# Restart a service
docker compose --env-file .env.production restart backend

# Update to latest images
docker compose --env-file .env.production pull
docker compose --env-file .env.production up -d
```

### Weekly Maintenance

```bash
# Check disk usage
df -h
docker system df

# Clean up unused resources
docker system prune -a

# Backup database
docker compose --env-file .env.production exec postgres pg_dump -U postgres land_marketplace > backup_$(date +%Y%m%d).sql
```

### Monthly Tasks

```bash
# Update system packages
sudo yum update -y  # Amazon Linux
# or: sudo apt update && sudo apt upgrade -y  # Ubuntu

# Verify SSL auto-renewal
sudo systemctl status certbot-renew.timer

# Review logs for issues
docker compose --env-file .env.production logs --since 30d | grep -i error
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
docker compose --env-file .env.production ps

# Restart everything
docker compose --env-file .env.production restart

# Stop everything
docker compose --env-file .env.production down

# Start everything
docker compose --env-file .env.production up -d

# View logs
docker compose --env-file .env.production logs -f [service-name]

# Execute command in container
docker compose --env-file .env.production exec [service-name] [command]
```

---

## ✨ Success Indicators

Your deployment is successful when:

✅ All 4 services show "Up (healthy)" status  
✅ Website loads at https://test.plotchoice.com  
✅ API responds at https://test.plotchoice.com/api/health  
✅ SSL certificate is valid (green padlock in browser)  
✅ No errors in `docker compose --env-file .env.production logs`  
✅ Database accepts connections  
✅ EBS volumes mounted and persisting data  

---

**🎉 Congratulations! Your Real Estate application is now deployed!**

For ongoing maintenance and operations, refer to the [README.md](./README.md) Quick Commands section.

--------------------------------------------------

## 🎯 Detailed Deployment Steps (Manual Approach)



### Step 1: Prepare EBS Volumes (15 minutes)

**SSH into EC2**:
```bash
ssh -i your-key.pem ec2-user@your-ec2-ip
```

**List attached volumes**:
```bash
lsblk
```

Expected output:
```
nvme0n1     259:0    0   30G  0 disk /
nvme1n1     259:1    0   20G  0 disk        ← postgres
nvme2n1     259:2    0    5G  0 disk        ← certs
```

**Format EBS volumes** (ONLY if new/unused):
```bash
sudo mkfs -t ext4 /dev/nvme1n1  # postgres volume
sudo mkfs -t ext4 /dev/nvme2n1  # certs volume
```

**Create mount directories**:
```bash
sudo mkdir -p /mnt/ebs/postgres
sudo mkdir -p /mnt/ebs/certs
sudo mkdir -p /mnt/ebs/certbot-webroot
```

**Get volume UUIDs** (save these values):
```bash
sudo blkid
```

You'll see output like:
```
/dev/nvme1n1: UUID="abc123def456" TYPE="ext4"
/dev/nvme2n1: UUID="xyz789uvw012" TYPE="ext4"
```

**Add volumes to /etc/fstab** for permanent mounting:
```bash
sudo nano /etc/fstab
```

Add these two lines at the end (replace UUIDs with your values):
```
# EBS volumes for land marketplace
UUID=abc123def456  /mnt/ebs/postgres  ext4  defaults,nofail  0  2
UUID=xyz789uvw012  /mnt/ebs/certs     ext4  defaults,nofail  0  2
```

Save with `Ctrl+O`, `Enter`, `Ctrl+X`

**Mount volumes**:
```bash
sudo mount -a
```

**Verify mounts**:
```bash
df -h | grep /mnt/ebs
```

Should show:
```
/dev/nvme1n1       20G  24K  20G   1% /mnt/ebs/postgres
/dev/nvme2n1        5G  12K   5G   1% /mnt/ebs/certs
```

**Set permissions**:
```bash
sudo chown -R 999:999 /mnt/ebs/postgres
sudo chmod 755 /mnt/ebs/certs
sudo chmod 755 /mnt/ebs/certbot-webroot
```

✅ **Step 1 Complete**: EBS volumes mounted and ready

---

### Step 2: Generate SSL Certificate (10 minutes)

**Install Certbot**:
```bash
sudo yum install -y certbot python3-certbot-nginx
# OR for Ubuntu:
# sudo apt-get install -y certbot python3-certbot-nginx
```

**Generate certificate** (BEFORE starting Docker):
```bash
sudo certbot certonly --standalone \
  -d test.plotchoice.com \
  -d www.test.plotchoice.com \
  --email admin@test.plotchoice.com \
  --agree-tos
```

**Copy to EBS mount**:
```bash
sudo cp -r /etc/letsencrypt/live/test.plotchoice.com /mnt/ebs/certs/live/
sudo cp -r /etc/letsencrypt/archive /mnt/ebs/certs/
sudo chown -R nobody:nobody /mnt/ebs/certs
```

**Setup auto-renewal**:
```bash
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer
```

**Verify certificate**:
```bash
ls -la /mnt/ebs/certs/live/test.plotchoice.com/
```

Should show: `cert.pem`, `chain.pem`, `fullchain.pem`, `privkey.pem`

✅ **Step 2 Complete**: SSL certificate ready on EBS

---

### Step 3: Install Docker (5 minutes)

**Install Docker** (if not already installed):
```bash
# For Amazon Linux
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker

# For Ubuntu
# sudo apt-get update
# sudo apt-get install -y docker.io
# sudo systemctl start docker
# sudo systemctl enable docker
```

# Install Docker Compose (V2)
# Modern Docker installations include 'docker compose' as a plugin. 
# If missing, follow: https://docs.docker.com/compose/install/linux/
docker compose version

**Add user to docker group**:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

**Verify installation**:
```bash
docker ps
docker compose version
```

✅ **Step 3 Complete**: Docker installed and running

---

### Step 3.25: Generate & Configure Secrets (5 minutes) - DO THIS ON LOCAL MACHINE

⚠️ **IMPORTANT: This step is done on your LOCAL machine BEFORE deploying to EC2**

**Step 1: Generate Secure Secrets**

On your local machine, in the docker-project/ folder:

```bash
# Generate secure random secrets
bash scripts/setup-secrets.sh
```

**Output example**:
```
════════════════════════════════════
Add these to your .env.production file:
════════════════════════════════════

# PostgreSQL Credentials
POSTGRES_USER=postgres
POSTGRES_PASSWORD=aB3xYz9mK2pQ5vN8wL1cD4eF6gH7

# JWT Secrets
JWT_ACCESS_SECRET=x9kL2mN5pQ8vW1aB4cD7eF0gH3jK6
JWT_REFRESH_SECRET=j8mN2pQ5tU6vW9yZ1bC4dE7fG0hI3
...
```

Option: Save to file for backup:
```bash
# The script will ask if you want to save
# Answer 'y' to save secrets to .env.production.secrets.txt
```

**Step 2: Create .env.production**

```bash
# Copy the example file
cp .env.production.example .env.production

# Edit with your preferred editor
nano .env.production
# or: code .env.production
# or: vim .env.production
```

**Step 3: Fill in Required Values**

In .env.production, update these values from setup-secrets.sh output:

```bash
# Copy from setup-secrets.sh output
POSTGRES_PASSWORD=aB3xYz9mK2pQ5vN8wL1cD4eF6gH7
JWT_ACCESS_SECRET=x9kL2mN5pQ8vW1aB4cD7eF0gH3jK6
JWT_REFRESH_SECRET=j8mN2pQ5tU6vW9yZ1bC4dE7fG0hI3
ENCRYPTION_KEY=z7mN2pQ5tU6vW9yZ1bC4dE7fG0hI3j5

# From https://resend.com (Email service)
RESEND_API_KEY=re_your_actual_api_key_from_resend

# Your email addresses
EMAIL_FROM=noreply@test.plotchoice.com
EMAIL_FROM_NAME=Real Estate Platform
ADMIN_EMAIL=admin@test.plotchoice.com
ADMIN_ALERT_EMAIL=alerts@test.plotchoice.com

# Your domain
DOMAIN=test.plotchoice.com

# If using AWS S3 (optional)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
S3_DOCS_BUCKET=your-bucket-name
S3_MEDIA_BUCKET=your-bucket-name
```

**Step 4: Protect the Secrets File**

Make sure .env.production is NOT committed to git:

```bash
# Add to .gitignore (if not already there)
echo ".env.production" >> .gitignore
echo ".env.production.secrets.txt" >> .gitignore

# Verify
git status  # Should NOT show .env.production
```

**Step 5: Back Up Secrets Securely**

Store your secrets in a secure location:

- **Password Manager**: 1Password, LastPass, Dashlane, Bitwarden
- **USB Drive**: Encrypted (VeraCrypt, BitLocker)
- **AWS Secrets Manager**: For production environments
- **Corporate Secret Store**: Vault, HashiCorp, etc.

⚠️ **NEVER:**
- Email secrets to anyone
- Share in Slack/Teams chat
- Store in unencrypted files
- Commit to git repository

✅ **Step 3.25 Complete**: Secrets generated and .env.production ready

---

### Step 3.5: Prepare Files to Copy to Server (2 minutes)

Before deploying, gather these files from your local machine:

**Essential files needed on EC2**:
```
docker-project/
├── docker-compose.yml          ⭐ REQUIRED - Service definitions
├── .env.production             ⭐ REQUIRED - Environment variables (you create/edit this)
│
└── nginx/                       ⭐ REQUIRED - Nginx configuration
    └── conf.d/
        └── default.conf        ⭐ REQUIRED - SSL/routing config
```

**Optional but recommended**:
```
docker-project/
├── .env.example                📖 Reference - keep for updating configs
├── README.md                   📖 Reference - quick commands
└── DEPLOYMENT_GUIDE.md         📖 This file - troubleshooting
```

**Do NOT copy** (leave on local machine only):
```
❌ RE-Backend/Dockerfile        - Not needed (image pre-built)
❌ RE-FrontEnd/Dockerfile      - Not needed (image pre-built)
❌ .git/                        - Not needed on EC2
```

**Complete directory structure on EC2**:
```
~/
└── real-state/                 ⭐ Clone repo here (or create this folder)
    └── docker-project/
        ├── docker-compose.yml       ✅ Essential
        ├── .env.production          ✅ Essential  
        ├── .env.example             ✅ Keep for reference
        ├── README.md                ✅ Keep for reference
        ├── DEPLOYMENT_GUIDE.md      ✅ Keep for troubleshooting
        │
        └── nginx/                   ✅ Essential
            ├── nginx.conf
            └── conf.d/
                └── default.conf

/mnt/ebs/                        ⭐ EBS Volumes (Optional for local, Required for Production)
├── postgres/                    ✅ Database data (persists)
├── certs/                       ✅ SSL certs mount point
└── certbot-webroot/            ✅ For cert renewal
```

**Summary**:
- ✅ 3 files are absolutely critical: `docker-compose.yml`, `.env.production`, `nginx/conf.d/default.conf`
- ✅ 1 folder is critical: `nginx/conf.d/`
- ✅ Keep reference files for troubleshooting
- ❌ Don't need Dockerfiles on EC2 (images are pre-built)

---

### Step 4: Copy Application Files and Configure (10 minutes)

⚠️ **IMPORTANT: Copy your prepared .env.production file from Step 3.25**

**Option A: Clone full repository** (if you have git access):
```bash
cd ~
git clone <your-repo-url>
cd real-state/docker-project

# Copy your prepared .env.production to EC2 (from local machine)
# Run this from your LOCAL machine (not EC2):
scp -i your-key.pem .env.production ec2-user@your-ec2-ip:~/real-state/docker-project/
```

**Option B: Copy only essential files** (if you prefer minimal):
```bash
# Create directory on EC2
mkdir -p ~/real-state/docker-project/nginx/conf.d
cd ~/real-state/docker-project

# Copy files from your local machine to EC2 using SCP
# Run these from your LOCAL machine:
scp -i your-key.pem docker-compose.yml ec2-user@your-ec2-ip:~/real-state/docker-project/
scp -i your-key.pem .env.production ec2-user@your-ec2-ip:~/real-state/docker-project/  # ⭐ Copy your secrets file
scp -i your-key.pem nginx/conf.d/default.conf ec2-user@your-ec2-ip:~/real-state/docker-project/nginx/conf.d/
scp -i your-key.pem .env.example ec2-user@your-ec2-ip:~/real-state/docker-project/
scp -i your-key.pem README.md ec2-user@your-ec2-ip:~/real-state/docker-project/
scp -i your-key.pem DEPLOYMENT_GUIDE.md ec2-user@your-ec2-ip:~/real-state/docker-project/
```

**Verify files are there** (back on EC2):
```bash
ls -la ~/real-state/docker-project/
# Should show: docker-compose.yml, .env.production, nginx/, .env.example, README.md
```

**Set secure permissions on .env.production**:
```bash
# Only owner can read this file
chmod 600 ~/real-state/docker-project/.env.production

# Verify permissions
ls -l .env.production
# Should show: -rw------- (600 permissions)
```

**Verify secrets are loaded**:
```bash
# Check if variables are set
grep "POSTGRES_PASSWORD=" .env.production
grep "JWT_ACCESS_SECRET=" .env.production

# Check Docker can see the variables
cd ~/real-state/docker-project
docker compose --env-file .env.production config | grep "POSTGRES_PASSWORD"
```

**Verify directory structure on EC2**:
```bash
ls -la ~/real-state/docker-project/

# Should show:
-rw-r--r-- docker-compose.yml
-rw------- .env.production          (note: 600 permissions)
-rw-r--r-- .env.example
-rw-r--r-- README.md
-rw-r--r-- DEPLOYMENT_GUIDE.md
drwxr-xr-x nginx/

# And nginx should have:
ls -la ~/real-state/docker-project/nginx/conf.d/
# Should show: default.conf
```

✅ **Step 4 Complete**: All files copied and configured

---

### Step 4.5: Test Configuration (Dry Run) - BEFORE Starting Services (5 minutes)

**Run validation tests** to ensure everything is configured correctly BEFORE running docker-compose:

**1. Validate docker-compose.yml syntax**:
```bash
cd ~/real-state/docker-project
docker compose --env-file .env.production config
```

This shows the complete configuration that will be deployed. Check for:
- ✅ No errors (should output valid YAML)
- ✅ All 4 services listed: nginx, postgres, backend, frontend
- ✅ All environment variables from .env.production loaded
- ✅ Volume mounts configured (named volumes or EBS paths)

**Expected output** (first 50 lines):
```yaml
services:
  nginx:
    image: nginx:1.25-alpine
    container_name: nginx-proxy
    ports:
    - 80:80
    - 443:443
    volumes:
    - cert_data:/etc/letsencrypt:ro
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    ...
  postgres:
    image: postgres:16-alpine
    container_name: postgres-db
    ...
  backend:
    container_name: backend-api
    ...
  frontend:
    container_name: frontend-app
    ...
```

**2. Check if docker images are available**:
```bash
docker compose --env-file .env.production config --services
# Should list: nginx, postgres, backend, frontend
```

**3. Test pulling/building images**:
```bash
# To build from source (newly added support):
docker compose build

# OR to pull from registry:
docker compose --env-file .env.production pull
```

This downloads images without running containers. It will show:
- ✅ Successfully pulled `nginx:1.25-alpine`
- ✅ Successfully pulled `postgres:16-alpine`
- ✅ Successfully pulled `real-estate-backend:latest`
- ✅ Successfully pulled `real-estate-frontend:latest`

If any image fails to pull, you'll see an error, which means images aren't available in your registry.

**4. Verify environment variables are loaded**:
```bash
docker compose --env-file .env.production config | grep -A 20 "environment:"
```

Should show all variables from `.env.production` like:
```
POSTGRES_PASSWORD: your-password
JWT_ACCESS_SECRET: your-secret
DOMAIN: test.plotchoice.com
...
```

**5. Check EBS volumes exist** (before docker-compose starts):
```bash
ls -la /mnt/ebs/
```

Should show:
```
drwxr-xr-x postgres/
drwxr-xr-x certs/
drwxr-xr-x certbot-webroot/
```

**6. Verify SSL certificates are in place**:
```bash
ls -la /mnt/ebs/certs/live/test.plotchoice.com/
```

Should show:
```
-rw-r--r-- cert.pem
-rw-r--r-- chain.pem
-rw-r--r-- fullchain.pem
-r--r--r-- privkey.pem
```

**7. Test individual image availability** (optional, but catches problems early):
```bash
docker pull nginx:1.25-alpine
docker pull postgres:16-alpine
docker pull real-estate-backend:latest
docker pull real-estate-frontend:latest
```

Each should show: `Status: Downloaded newer image` or `Status: Image is up to date`

**Summary of Dry-Run Validation**:

```bash
# Complete validation script (copy & paste all at once):
echo "=== Validating Configuration ==="
docker compose --env-file .env.production config > /dev/null && echo "✅ docker-compose.yml is valid" || echo "❌ Invalid YAML syntax"

echo ""
echo "=== Checking Services ==="
docker compose --env-file .env.production config --services

echo ""
echo "=== Verifying Volume Mount Points ==="
ls -la /mnt/ebs/ && echo "✅ EBS mount point exists" || echo "⚠️ EBS mount point missing (using local volumes)"

echo ""
echo "=== Verifying SSL Certificates ==="
ls -la /mnt/ebs/certs/live/test.plotchoice.com/ && echo "✅ SSL certificates found" || echo "❌ SSL certificates missing"

echo ""
echo "=== Environment Variables Sample ==="
docker compose --env-file .env.production config | grep "DOMAIN:" || echo "❌ Environment variables not loaded"

echo ""
echo "=== Docker Ready? ==="
docker ps && echo "✅ Docker daemon running" || echo "❌ Docker not running"
docker compose version && echo "✅ Docker Compose installed" || echo "❌ Docker Compose not installed"
```

**If any validation fails**:
- ❌ **Invalid YAML syntax** → Check `docker-compose.yml` for typos
- ❌ **EBS volumes missing** → Run Step 1 again (mount volumes)
- ❌ **SSL certificates missing** → Run Step 2 again (generate certs)
- ❌ **Environment variables not loaded** → Check `.env.production` exists and has values
- ❌ **Images not available** → Check your Docker registry, or build images locally

**Do NOT proceed to Step 5 until all validations pass!**

✅ **Step 4.5 Complete**: Configuration validated and ready

---

### Step 5: Start Docker Services (5 minutes)

**Start all services**:
```bash
docker compose --env-file .env.production up -d
```

**Wait for services to start** (first start takes 30-45 seconds):
```bash
sleep 10
docker compose --env-file .env.production ps
```

Expected output:
```
NAME              IMAGE                STATUS
nginx-proxy       nginx:1.25           Up 2 minutes
backend-api       real-estate-backend  Up 1 minute
frontend-app      real-estate-frontend Up 1 minute
postgres-db       postgres:16          Up 3 minutes
```

**Check logs for errors**:
```bash
docker compose --env-file .env.production logs --tail=50
```

Should see no errors (warnings about migrations are normal)

✅ **Step 5 Complete**: All services running

---

## ✅ Post-Deployment Validation (10 minutes)

### Verify Each Service

**1. Check all services are running**:
```bash
docker compose --env-file .env.production ps
# All should show "Up"
```

**2. Test HTTP → HTTPS redirect**:
```bash
curl -I http://test.plotchoice.com
# Should show 301 or 302 redirect to https
```

**3. Test HTTPS connection**:
```bash
curl -I https://test.plotchoice.com
# Should show 200 OK
```

**4. Verify SSL certificate**:
```bash
echo | openssl s_client -servername test.plotchoice.com \
  -connect test.plotchoice.com:443 2>/dev/null | \
  openssl x509 -noout -dates
# Should show: notBefore and notAfter dates
```

**5. Check database is accessible**:
```bash
docker compose --env-file .env.production exec postgres pg_isready -U postgres
# Should show "accepting connections"
```

**6. Verify data persists on EBS**:
```bash
ls -la /mnt/ebs/postgres/base/
# Should show database files
```

**7. Check backend API**:
```bash
curl -I https://test.plotchoice.com/api
# Should show 200 or 404 (any response means API is working)
```

**8. Frontend loads in browser**:
```
Open browser: https://test.plotchoice.com
Should see: Your application homepage
No SSL warnings should appear
```

### If Something Fails

**Check logs**:
```bash
# All services
docker compose --env-file .env.production logs -f

# Specific service
docker compose --env-file .env.production logs backend
docker compose --env-file .env.production logs postgres
docker compose --env-file .env.production logs nginx
```

**Restart all services**:
```bash
docker compose --env-file .env.production down
docker compose --env-file .env.production up -d
```

**See Troubleshooting section below for specific errors**

---

## 📊 Monitoring & Maintenance

### Daily Operations

**View logs**:
```bash
docker compose --env-file .env.production logs -f          # Follow all logs
docker compose --env-file .env.production logs --tail=100  # Last 100 lines
```

**Check service status**:
```bash
docker compose --env-file .env.production ps
docker stats                    # Resource usage
```

**Quick commands**:
```bash
docker compose --env-file .env.production up -d            # Start all
docker compose --env-file .env.production down             # Stop all
docker compose --env-file .env.production restart backend  # Restart one service
```

### Weekly Tasks

**Check certificate renewal**:
```bash
sudo certbot certificates
# Should show certificate not expiring soon
```

**Check disk usage**:
```bash
df -h | grep /mnt/ebs
# Should have plenty of free space
```

**Check system logs**:
```bash
docker compose --env-file .env.production logs | grep -i error
# Should show minimal errors
```

### Monthly Tasks

**Verify auto-renewal is working**:
```bash
sudo systemctl status certbot-renew.timer
# Should show "active (running)"
```

**Check certbot renewal log**:
```bash
sudo tail -20 /var/log/letsencrypt/letsencrypt.log
```

**Test database backup**:
```bash
docker compose --env-file .env.production exec postgres pg_dump -U postgres -d land_marketplace > /tmp/test_backup.sql
ls -lh /tmp/test_backup.sql
```

---

## 🛠️ Troubleshooting

### Problem: EBS volumes not mounted after reboot

**Check current mounts**:
```bash
mount | grep /mnt/ebs
```

**Verify fstab is correct**:
```bash
cat /etc/fstab | grep ebs
# Should show both UUIDs
```

**Manually mount if needed**:
```bash
sudo mount -a
df -h | grep /mnt/ebs
```

**If still not working**:
```bash
sudo blkid  # Check UUIDs match fstab
sudo fsck -n /dev/nvme1n1  # Check filesystem (don't use -y)
```

### Problem: Services won't start

**Check logs**:
```bash
docker compose --env-file .env.production logs
```

**Common causes**:
- ❌ EBS volumes not mounted → Mount with `sudo mount -a`
- ❌ SSL cert not found → Verify `/mnt/ebs/certs/live/test.plotchoice.com/` exists
- ❌ Port already in use → `sudo netstat -tlnp | grep -E ':80|:443'`
- ❌ Permissions issue → Check `/mnt/ebs/postgres` has correct owner

**Solution**:
```bash
docker compose --env-file .env.production down
# Fix the issue
docker compose --env-file .env.production up -d
```

### Problem: SSL certificate error

**Verify cert exists**:
```bash
ls -la /mnt/ebs/certs/live/test.plotchoice.com/
# Should show: cert.pem, chain.pem, fullchain.pem, privkey.pem
```

**Check Nginx can read it**:
```bash
docker exec nginx-server ls -la /etc/letsencrypt/live/test.plotchoice.com/
```

**Force certificate renewal** (if needed):
```bash
sudo certbot renew --force-renewal
sudo cp -r /etc/letsencrypt/live/test.plotchoice.com /mnt/ebs/certs/live/
docker compose --env-file .env.production restart nginx-server
```

### Problem: Database connection error

**Check PostgreSQL is running**:
```bash
docker compose --env-file .env.production ps postgres
# Should show "Up"
```

**Test database connection**:
```bash
docker compose --env-file .env.production exec postgres psql -U postgres -c "SELECT 1"
# Should return "1"
```

**Check data on EBS**:
```bash
ls -la /mnt/ebs/postgres/base/
# Should show database files
```

**Verify environment variables**:
```bash
docker compose --env-file .env.production config | grep POSTGRES
```

### Problem: Backend/Frontend not communicating

**Check backend logs**:
```bash
docker compose --env-file .env.production logs backend
# Look for connection errors
```

**Test API from container**:
```bash
docker exec nginx-server curl http://backend:5000/health
# Should return something (not error)
```

**Verify environment variables**:
```bash
docker compose --env-file .env.production config
# Check NEXT_PUBLIC_API_URL matches
```

**Restart services**:
```bash
docker compose --env-file .env.production restart backend frontend
```

### Problem: High disk usage

**Check what's taking space**:
```bash
sudo du -sh /mnt/ebs/postgres/*
sudo du -sh /mnt/ebs/certs/*
```

**Database getting too large**:
```bash
# Analyze largest tables
docker compose --env-file .env.production exec postgres psql -U postgres -d land_marketplace -c "
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;"
```

**Clean Docker unused data**:
```bash
docker system df
docker system prune -a  # Clean unused images/containers
```

## 🔐 Security Checklist

Verify these before going to production:

- [ ] POSTGRES_PASSWORD changed from default
- [ ] JWT_ACCESS_SECRET is a strong random string
- [ ] JWT_REFRESH_SECRET is a strong random string
- [ ] .env.production file permissions are 600: `chmod 600 .env.production`
- [ ] HTTPS is enforced (HTTP redirects to HTTPS)
- [ ] SSL certificate is valid (no browser warnings)
- [ ] Certbot auto-renewal is active: `sudo systemctl status certbot-renew.timer`
- [ ] Security groups only allow 80/443 from world, 22 from admin IPs
- [ ] No secrets visible in logs: `docker compose --env-file .env.production logs | grep -i password` (should return nothing)
- [ ] Regular backups planned and tested

---

## ✨ Success Indicators

Your deployment is complete when:

✅ All 4 containers running (`docker compose --env-file .env.production ps`)  
✅ HTTPS works on test.plotchoice.com (no SSL warnings)  
✅ Frontend loads and responds  
✅ Backend API responds to requests  
✅ Database is accessible  
✅ Data persists on EBS volumes  
✅ Certbot auto-renewal is configured  
✅ No errors in logs  

---

## 📌 Files & Dependencies Reference

### Critical Files (Must Be Present)

| File | Location | Purpose | Must Copy? |
|------|----------|---------|-----------|
| `docker-compose.yml` | `docker-project/` | Defines all 4 services (nginx, postgres, backend, frontend) | ✅ YES |
| `.env.production` | `docker-project/` | Environment variables for the app | ✅ YES (you create) |
| `default.conf` | `docker-project/nginx/conf.d/` | Nginx routing, SSL config, domain settings | ✅ YES |
| `nginx.conf` | `docker-project/nginx/` | Nginx main configuration | ✅ YES (via docker-compose volume) |

### Reference Files (Helpful but Not Required)

| File | Location | Purpose | Copy? |
|------|----------|---------|-------|
| `.env.example` | `docker-project/` | Template for .env.production | 📖 Optional |
| `README.md` | `docker-project/` | Quick reference, architecture | 📖 Optional |
| `DEPLOYMENT_GUIDE.md` | `docker-project/` | This file - troubleshooting | 📖 Optional |

### Files NOT Needed on EC2

| File | Reason |
|------|--------|
| `RE-Backend/Dockerfile` | Images are pre-built, pulled from registry |
| `RE-FrontEnd/Dockerfile` | Images are pre-built, pulled from registry |
| `.git/` | No version control needed on EC2 |
| `scripts/` folder | No setup scripts needed (manual steps) |
| `backups/` folder | Backups created at runtime |

---

## 📂 Complete Server File & Folder Structure

### Required Directory Structure

```
/home/ec2-user/
└── real-state/
    └── docker-project/
        ├── docker-compose.yml           ← Service definitions (REQUIRED)
        ├── .env.production              ← Environment config (REQUIRED - you create)
        ├── .env.example                 ← Template (optional reference)
        ├── README.md                    ← Quick guide (optional reference)
        ├── DEPLOYMENT_GUIDE.md          ← This guide (optional reference)
        │
        └── nginx/                       ← Nginx config (REQUIRED)
            ├── nginx.conf               ← Nginx main config
            └── conf.d/
                └── default.conf         ← SSL/routing/domains (REQUIRED)

/mnt/ebs/                               ← EBS Volumes (created in Step 1)
├── postgres/                            ← Database data
│   ├── base/
│   ├── global/
│   ├── pg_wal/
│   └── ...
├── certs/                               ← SSL certificates
│   ├── live/
│   │   └── test.plotchoice.com/
│   │       ├── cert.pem
│   │       ├── chain.pem
│   │       ├── fullchain.pem
│   │       └── privkey.pem
│   ├── archive/
│   └── renewal/
└── certbot-webroot/                     ← ACME challenges
```

### What Docker Creates

When you run `docker compose --env-file .env.production up -d`, Docker automatically creates:

```
Containers:
- nginx-server      (Nginx 1.25-alpine)
- backend-server    (Your backend image)
- frontend-server   (Your frontend image)
- postgres-db       (PostgreSQL 16-alpine)

Networks:
- frontend-network  (Nginx ↔ Frontend)
- backend-network   (Backend ↔ PostgreSQL)

Volumes:
- postgres_data     → /mnt/ebs/postgres (mounted)
- certs_data        → /mnt/ebs/certs (mounted)
```

---

## 📋 File Dependencies

### docker-compose.yml depends on:
- ✅ `.env.production` - For environment variables
- ✅ `nginx/conf.d/default.conf` - For Nginx config
- ✅ `/mnt/ebs/certs/` - For SSL certificates (created in Step 2)
- ✅ `/mnt/ebs/postgres/` - For database data (created in Step 1)
- ✅ Pre-built Docker images (pulled from registry)

### .env.production depends on:
- ✅ POSTGRES_PASSWORD - Your secure password (you set)
- ✅ JWT secrets - Session management (you generate)
- ✅ DOMAIN - test.plotchoice.com
- ✅ API keys - Email, AWS (optional, you provide)

### nginx/conf.d/default.conf depends on:
- ✅ /mnt/ebs/certs/live/test.plotchoice.com/ - SSL certificates
- ✅ backend service - For proxying API requests
- ✅ frontend service - For serving static files

---

## 📌 Key Locations & Verification

**Application directory** (where you run docker-compose from):
```bash
cd ~/real-state/docker-project
ls -la
# You should see: docker-compose.yml, .env.production, nginx/ folder
```

**EBS volumes** (where data persists):
```bash
ls -la /mnt/ebs/
# You should see: postgres/, certs/, certbot-webroot/
```

**SSL certificates** (for HTTPS):
```bash
ls -la /mnt/ebs/certs/live/test.plotchoice.com/
# You should see: cert.pem, chain.pem, fullchain.pem, privkey.pem
```

**Environment configuration**:
```bash
cat ~/real-state/docker-project/.env.production | head -20
# Should show your configured values (passwords hidden)
```

---

## 📚 File Checklist

Before running `docker compose --env-file .env.production up -d`, verify you have:

- [ ] **docker-compose.yml** present in `~/real-state/docker-project/`
- [ ] **nginx/conf.d/default.conf** present and has correct domain name
- [ ] **.env.production** created and configured with passwords
- [ ] **.env.production** has permissions 600: `chmod 600 .env.production`
- [ ] **/mnt/ebs/postgres/** directory exists and is empty (for first run)
- [ ] **/mnt/ebs/certs/live/test.plotchoice.com/** has SSL cert files
- [ ] `/etc/fstab` has EBS mount entries (for persistence)
- [ ] Docker is installed and running: `docker ps`
- [ ] Docker Compose is installed: `docker-compose --version`
- [ ] All 4 containers can be seen in config: `docker compose --env-file .env.production config`

---

## 🆘 Quick Commands Reference

```bash
# Start/Stop
docker compose --env-file .env.production up -d                    # Start all
docker compose --env-file .env.production down                     # Stop all
docker compose --env-file .env.production restart <service>        # Restart one

# Logs
docker compose --env-file .env.production logs -f                  # Follow all
docker compose --env-file .env.production logs <service>           # Single service
docker compose --env-file .env.production logs --tail=100          # Last 100 lines

# Status
docker compose --env-file .env.production ps                       # Service status
docker stats                            # Resource usage
df -h | grep /mnt/ebs                  # Disk usage

# Database
docker compose --env-file .env.production exec postgres psql -U postgres  # Connect to DB
docker compose --env-file .env.production exec postgres pg_dump -U postgres -d land_marketplace > backup.sql

# Certificates
sudo certbot certificates               # List certs
sudo certbot renew --force-renewal      # Force renewal
sudo systemctl status certbot-renew.timer  # Check auto-renewal

# Cleanup
docker system prune -a                  # Clean unused
docker volume prune                     # Clean volumes
```

---

## 📞 Need Help?

**Check error logs first**:
```bash
docker compose --env-file .env.production logs -f
```

**Verify each component**:
1. EBS mounted? → `df -h | grep /mnt/ebs`
2. Cert exists? → `ls -la /mnt/ebs/certs/live/test.plotchoice.com/`
3. Services running? → `docker compose --env-file .env.production ps`
4. Firewall open? → Check AWS Security Groups

**Restart if stuck**:
```bash
docker compose --env-file .env.production down
docker compose --env-file .env.production up -d
docker compose --env-file .env.production logs -f
```

---

**🎉 You're ready to deploy! Start from Step 1 above.**
