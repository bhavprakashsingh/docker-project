# EC2 Setup Guide - Docker, docker-compose & Certbot

Complete guide to set up Docker, docker-compose, and SSL certificates on AWS EC2.

## Table of Contents
- [⚠️ Prerequisites: EBS Mounting (DO FIRST)](#prerequisites-ebs-mounting-do-first)
- [Quick Start (Automated)](#quick-start-automated)
- [Manual Setup (Step-by-Step)](#manual-setup-step-by-step)
- [Verification & Testing](#verification--testing)
- [Troubleshooting](#troubleshooting)

---

## ⚠️ Prerequisites: EBS Mounting (DO FIRST)

**CRITICAL: Mount EBS volumes BEFORE running any other setup scripts**

Your 2 EBS volumes must be mounted with persistent fstab configuration before Docker or Certbot can use them:
- `/mnt/ebs/postgres` - For PostgreSQL database storage (20GB)
- `/mnt/ebs/certs` - For SSL certificates from Certbot (5GB)

### Step 1: Mount EBS Volumes (5 minutes)

```bash
# Run EBS mounting script (interactive)
sudo bash scripts/setup-ebs.sh

# The script will:
# 1. List available EBS volumes
# 2. Ask you to identify which device is which (e.g., /dev/nvme1n1, /dev/nvme2n1)
# 3. Format the volumes if needed
# 4. Mount them at /mnt/ebs/postgres and /mnt/ebs/certs
# 5. Add entries to /etc/fstab for persistent mounting on EC2 reboot
# 6. Verify everything works
```

**Expected Output:**
```
Available block devices:
NAME        SIZE TYPE STATE
nvme1n1    20G disk live    ← postgres volume
nvme2n1     5G disk live    ← certs volume

Enter device name for postgres volume (e.g., /dev/nvme1n1): /dev/nvme1n1
Enter device name for certs volume (e.g., /dev/nvme2n1): /dev/nvme2n1
Proceed with mounting? (y/N) y

✅ Postgres volume mounted
✅ Certs volume mounted
✅ EBS Mounting COMPLETE
```

**Verify mounting succeeded:**
```bash
# Check mounted volumes
df -h | grep ebs

# Check fstab entries
sudo cat /etc/fstab | grep ebs
```

Now proceed to Docker setup below.

---

## Quick Start (Automated)

The fastest way to set up everything in one command:

### Prerequisites
- ✅ **EBS volumes ALREADY MOUNTED** (via setup-ebs.sh above)
- SSH access to EC2 instance
- Domain name with A record pointing to EC2 instance
- Valid email for Certbot notifications

### Single Command Setup

```bash
# IMPORTANT: Only run this AFTER setup-ebs.sh completes successfully

# Run the complete setup (replace with your domain and email)
sudo bash scripts/setup-all.sh test.plotchoice.com admin@example.com
```

**What it does:**
1. Updates system packages
2. Installs Docker and docker-compose
3. Configures Docker daemon for auto-start on reboot
4. Installs Certbot and generates SSL certificate
5. Enables automatic certificate renewal
6. Tests everything and displays summary

**Duration:** 5-10 minutes

---

## 🔐 Generate Secrets (BEFORE Deployment)

Before deploying, you must generate strong random secrets for passwords and API keys.

### Step 1: Generate Secure Secrets (Local Machine)

Run on your LOCAL machine (not EC2):

```bash
# From docker-project/ directory
bash scripts/setup-secrets.sh
```

**What it does:**
1. Generates 24-character PostgreSQL password
2. Generates 32-byte JWT access secret
3. Generates 32-byte JWT refresh secret
4. Generates 32-byte encryption key
5. Displays all secrets in copyable format
6. Option to save to `.env.production.secrets.txt`

### Step 2: Create .env.production (Local Machine)

```bash
# Copy the example file
cp .env.production.example .env.production

# Edit the file and add your secrets
nano .env.production  # or use your preferred editor

# Update these REQUIRED values:
# - POSTGRES_PASSWORD (from setup-secrets.sh output)
# - JWT_ACCESS_SECRET (from setup-secrets.sh output)
# - JWT_REFRESH_SECRET (from setup-secrets.sh output)
# - ENCRYPTION_KEY (from setup-secrets.sh output)
# - RESEND_API_KEY (from https://resend.com)
# - EMAIL_FROM (your domain email)
# - EMAIL addresses
# - DOMAIN (your domain)
# - AWS keys (if using S3)
```

### Step 3: Copy .env.production to EC2

```bash
# From your local machine
scp -i your-ec2-key.pem .env.production ec2-user@your-ec2-ip:~/app/

# Set secure permissions
ssh -i your-ec2-key.pem ec2-user@your-ec2-ip
chmod 600 .env.production
```

### 🔐 Security Best Practices

```bash
# Add to .gitignore (NEVER commit secrets to git)
echo ".env.production" >> .gitignore
echo ".env.production.secrets.txt" >> .gitignore

# Store backup securely
# - Password manager (1Password, LastPass, Dashlane)
# - Encrypted USB drive
# - AWS Secrets Manager (for production)

# Rotate secrets regularly
# - Change POSTGRES_PASSWORD quarterly
# - Regenerate JWT secrets if compromised
# - Update API keys periodically
```

---

## Manual Setup (Step-by-Step)

If you prefer to understand each step or troubleshoot specific parts:

### Step 1: Docker Installation

#### 1.1 Update System
```bash
sudo apt-get update
sudo apt-get upgrade -y
```

#### 1.2 Install Prerequisites
```bash
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https
```

#### 1.3 Add Docker GPG Key
```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
```

#### 1.4 Add Docker Repository
```bash
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
```

#### 1.5 Install Docker & docker-compose
```bash
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin
```

#### 1.6 Enable Auto-Start on Reboot
```bash
# Enable Docker daemon to start on reboot
sudo systemctl enable docker
sudo systemctl start docker

# Enable containerd auto-start
sudo systemctl enable containerd
sudo systemctl restart containerd
```

#### 1.7 Verify Installation
```bash
# Check Docker version
docker --version

# Check docker-compose version
docker compose version

# Test Docker is running
docker ps
```

**Expected Output:**
```
Docker version 27.x.x, build xxxxxxx
Docker Compose version 3.x.x
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
(empty - no containers running yet)
```

---

### Step 2: Certbot & SSL Certificate Setup

#### 2.1 Create Certificate Directory
```bash
sudo mkdir -p /mnt/ebs/certs
sudo chmod 755 /mnt/ebs/certs
```

#### 2.2 Install Certbot
```bash
sudo apt-get install -y certbot python3-certbot-nginx
```

#### 2.3 Generate SSL Certificate
```bash
# Replace test.plotchoice.com and admin@example.com with your values
sudo certbot certonly \
    --standalone \
    --agree-tos \
    --no-eff-email \
    --email admin@example.com \
    -d test.plotchoice.com \
    --cert-path /mnt/ebs/certs
```

**What you'll see:**
- Certbot will connect to Let's Encrypt servers
- Takes 30-60 seconds to validate domain
- Certificate files created in `/mnt/ebs/certs/live/test.plotchoice.com/`

**Expected Output:**
```
Successfully received certificate.
Certificate is saved at: /mnt/ebs/certs/live/test.plotchoice.com/fullchain.pem
Key is saved at: /mnt/ebs/certs/live/test.plotchoice.com/privkey.pem
```

#### 2.4 Configure Auto-Renewal
```bash
# Enable Certbot auto-renewal timer
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer

# Verify timer is active
sudo systemctl status certbot-renew.timer
```

#### 2.5 Test Auto-Renewal (Dry-Run)
```bash
sudo certbot renew --dry-run
```

**Expected Output:**
```
The following certificates are not due for renewal yet
But they may be due for renewal after https://example.com/...
(dry run mode)
```

#### 2.6 Verify Certificate
```bash
# View certificate expiration
openssl x509 -in /mnt/ebs/certs/live/test.plotchoice.com/fullchain.pem \
    -noout -dates

# List all Certbot certificates
sudo certbot certificates
```

---

## Verification & Testing

### Test 1: Docker Installation
```bash
# Check Docker version
docker --version

# Check containerd status
sudo systemctl status containerd

# Check if Docker starts on boot
sudo systemctl is-enabled docker
# Expected: enabled
```

### Test 2: SSL Certificate
```bash
# Verify certificate location
ls -la /mnt/ebs/certs/live/test.plotchoice.com/

# Expected files:
# -rw-r--r-- cert.pem
# -rw-r--r-- chain.pem
# -rw-r--r-- fullchain.pem
# -r-------- privkey.pem

# Check certificate details
openssl x509 -text -noout \
    -in /mnt/ebs/certs/live/test.plotchoice.com/fullchain.pem
```

### Test 3: Auto-Renewal Configuration
```bash
# View renewal schedule
sudo systemctl list-timers certbot-renew.timer

# View renewal logs
journalctl -u certbot-renew.timer --no-pager

# Test renewal (dry-run)
sudo certbot renew --dry-run
```

### Test 4: Auto-Start After Reboot
```bash
# Reboot EC2 instance
sudo reboot

# After reboot, verify Docker is running
docker ps
sudo systemctl status docker
```

---

## Troubleshooting

### Docker Issues

#### Problem: "docker: command not found"
```bash
# Solution: Docker not installed correctly
sudo apt-cache policy docker-ce
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

#### Problem: "Cannot connect to Docker daemon"
```bash
# Solution: Docker daemon not running
sudo systemctl start docker
sudo systemctl status docker

# Make user part of docker group (optional)
sudo usermod -aG docker $USER
newgrp docker
```

#### Problem: "Docker not starting on reboot"
```bash
# Solution: Enable auto-start
sudo systemctl enable docker
sudo systemctl enable containerd

# Verify
sudo systemctl is-enabled docker
# Expected: enabled
```

### Certbot Issues

#### Problem: "Connection refused" during certificate generation
```bash
# Solution: Ensure domain A record points to EC2 instance
dig test.plotchoice.com
# Should show your EC2 instance IP

# Verify DNS is working
nslookup test.plotchoice.com
```

#### Problem: "Certificate already exists"
```bash
# Solution: Use --force-renewal
sudo certbot certonly \
    --standalone \
    --force-renewal \
    --agree-tos \
    --no-eff-email \
    --email admin@example.com \
    -d test.plotchoice.com \
    --cert-path /mnt/ebs/certs
```

#### Problem: "Auto-renewal not working"
```bash
# Check timer status
sudo systemctl status certbot-renew.timer

# View renewal logs
journalctl -u certbot-renew.timer -n 50

# Test renewal manually (dry-run)
sudo certbot renew --dry-run

# Enable timer if disabled
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer
```

#### Problem: "Certificate permissions denied"
```bash
# Fix certificate permissions
sudo chmod 644 /mnt/ebs/certs/live/test.plotchoice.com/fullchain.pem
sudo chmod 600 /mnt/ebs/certs/live/test.plotchoice.com/privkey.pem

# Verify
ls -la /mnt/ebs/certs/live/test.plotchoice.com/
```

---

## Common Commands Reference

### Docker Commands
```bash
# Check Docker status
docker ps
docker ps -a  # All containers

# Check Docker logs
docker compose logs -f

# Stop/Start services
docker compose stop
docker compose start

# View Docker system info
docker system df
docker info
```

### Certbot Commands
```bash
# List all certificates
sudo certbot certificates

# Renew specific domain (dry-run)
sudo certbot renew --cert-name test.plotchoice.com --dry-run

# Renew all certificates
sudo certbot renew

# View renewal schedule
sudo systemctl list-timers certbot-renew.timer

# View renewal logs
journalctl -u certbot-renew.timer -n 20
```

### System Commands
```bash
# Check system logs
sudo journalctl -xe

# View service status
sudo systemctl status docker
sudo systemctl status certbot-renew.timer

# Check if services auto-start on boot
sudo systemctl is-enabled docker
sudo systemctl is-enabled certbot-renew.timer

# Enable auto-start
sudo systemctl enable docker
sudo systemctl enable certbot-renew.timer
```

---

## Security Best Practices

### File Permissions
```bash
# Set proper permissions on certificate directory
sudo chown -R root:root /mnt/ebs/certs
sudo chmod 755 /mnt/ebs/certs
sudo chmod 755 /mnt/ebs/certs/live
sudo chmod 755 /mnt/ebs/certs/live/test.plotchoice.com

# Private key should be readable only by root and nginx
sudo chmod 600 /mnt/ebs/certs/live/test.plotchoice.com/privkey.pem
```

### Docker Security
```bash
# Remove unused images and containers
docker system prune -a

# View resource usage
docker stats

# Check for security vulnerabilities
docker scout cves <image-name>
```

### Certificate Security
```bash
# Monitor certificate expiration
sudo certbot certificates

# Set up renewal notifications
# Certbot sends email 7 days before expiration (configured with --email)

# Test renewal before actual expiration
sudo certbot renew --dry-run
```

---

## Next Steps

After completing setup:

1. ✅ Docker and docker-compose configured
2. ✅ SSL certificate generated with auto-renewal
3. ⬜ Prepare EBS volumes for database storage
4. ⬜ Copy docker-compose.yml and configuration files
5. ⬜ Set up environment variables (.env.production)
6. ⬜ Start Docker services
7. ⬜ Verify all services are running

Refer to [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for complete deployment instructions.

---

## Support & Monitoring

### Check everything is working
```bash
# All three should show "enabled"
sudo systemctl is-enabled docker
sudo systemctl is-enabled certbot-renew.timer
sudo systemctl is-enabled containerd

# Should show certificate valid for at least 30 days
sudo certbot certificates
```

### Ongoing maintenance
- **Weekly:** Check certificate expiration: `sudo certbot certificates`
- **Monthly:** Review Docker security: `docker system df` and `docker image prune`
- **Quarterly:** Review and update Docker versions
- **Yearly:** Audit container security with `docker scout`

---

**Document Updated:** April 2026
**Target Domain:** test.plotchoice.com
**Docker Compose Version:** v3.8+
