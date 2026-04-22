# 🎯 Step-by-Step Deployment Instructions

Follow these steps one by one. Complete each step before moving to the next.

---

## ✅ Step 1: Generate Secure Secrets (5 minutes)

**Location**: Your local Windows machine (WSL terminal)

### Instructions:

1. Open WSL (Ubuntu/Debian) terminal
2. Navigate to your project directory:
   ```bash
   cd /mnt/c/Users/BhavPrakashSingh/Documents/CA3S/CA3S/real-state/docker-project
   ```

3. Run the secret generation script:
   ```bash
   bash scripts/setup-secrets.sh
   ```

4. When asked "Save secrets to .env.production.secrets.txt? (y/N)", type `y` and press Enter

5. **COPY AND SAVE** all the generated values. You'll see output like:
   ```
   POSTGRES_PASSWORD=aB3xYz9mK2pQ5vN8wL1cD4eF6gH7
   JWT_ACCESS_SECRET=x9kL2mN5pQ8vW1aB4cD7eF0gH3jK6
   JWT_REFRESH_SECRET=j8mN2pQ5tU6vW9yZ1bC4dE7fG0hI3
   ENCRYPTION_KEY=z7mN2pQ5tU6vW9yZ1bC4dE7fG0hI3j5
   ```

6. Keep these values handy - you'll need them in Step 2

### ✅ Completion Check:
- [ ] Script ran successfully
- [ ] Secrets saved to `.env.production.secrets.txt`
- [ ] You have copied all the generated values

**Once complete, proceed to Step 2 below.**

---

## 📝 Step 2: Create .env.production File (10 minutes)

**Location**: Your local Windows machine

### Instructions:

1. In VSCode, create a new file: `docker-project/.env.production`

2. Copy the content from `docker-project/.env` as a starting point

3. Update the following values with the secrets you generated in Step 1:

   ```bash
   # Database - REPLACE with generated password
   POSTGRES_PASSWORD=<PASTE_YOUR_GENERATED_PASSWORD>
   DATABASE_URL=postgresql://postgres:<PASTE_SAME_PASSWORD>@postgres:5432/land_marketplace?schema=public
   
   # JWT Secrets - REPLACE with generated secrets
   JWT_ACCESS_SECRET=<PASTE_YOUR_GENERATED_JWT_ACCESS_SECRET>
   JWT_REFRESH_SECRET=<PASTE_YOUR_GENERATED_JWT_REFRESH_SECRET>
   
   # Encryption - REPLACE with generated key
   ENCRYPTION_KEY=<PASTE_YOUR_GENERATED_ENCRYPTION_KEY>
   ```

4. Update these additional values:

   ```bash
   # Email Configuration (Get API key from https://resend.com)
   RESEND_API_KEY=re_your_actual_api_key_from_resend
   EMAIL_FROM=noreply@test.plotchoice.com
   ADMIN_EMAIL=admin@test.plotchoice.com
   ADMIN_ALERT_EMAIL=alerts@test.plotchoice.com
   
   # AWS S3 (Optional - only if using file uploads)
   AWS_ACCESS_KEY_ID=your_aws_access_key_id
   AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
   S3_DOCS_BUCKET=your-docs-bucket-name
   S3_MEDIA_BUCKET=your-media-bucket-name
   ```

5. Verify these URLs are correct:
   ```bash
   APP_URL=https://test.plotchoice.com
   CLIENT_URL=https://test.plotchoice.com
   NEXT_PUBLIC_API_URL=https://test.plotchoice.com/api
   NEXT_PUBLIC_SITE_URL=https://test.plotchoice.com
   DOMAIN=test.plotchoice.com
   ```

6. Save the file

7. Set secure permissions (in WSL):
   ```bash
   cd /mnt/c/Users/BhavPrakashSingh/Documents/CA3S/CA3S/real-state/docker-project
   chmod 600 .env.production
   ```

### ✅ Completion Check:
- [ ] `.env.production` file created
- [ ] All secrets from Step 1 pasted in
- [ ] Email configuration updated
- [ ] Domain URLs verified
- [ ] File permissions set to 600

**Once complete, proceed to Step 3 below.**

---

## 🐳 Step 3: Build Docker Images (20-30 minutes)

**Location**: Your local Windows machine (WSL terminal)

Your docker-compose.yml expects pre-built images. You have two options:

### Option A: Build Images Locally (Recommended)

1. **Build Backend Image**:
   ```bash
   cd /mnt/c/Users/BhavPrakashSingh/Documents/CA3S/CA3S/real-state/RE-Backend
   docker build -t real-estate-backend:latest .
   ```

2. **Build Frontend Image**:
   ```bash
   cd /mnt/c/Users/BhavPrakashSingh/Documents/CA3S/CA3S/real-state/RE-FrontEnd
   docker build -t real-estate-frontend:latest \
     --build-arg NEXT_PUBLIC_API_URL=https://test.plotchoice.com/api \
     --build-arg NEXT_PUBLIC_SITE_URL=https://test.plotchoice.com \
     --build-arg INTERNAL_API_URL=http://backend:5000 \
     .
   ```

3. **Verify images built**:
   ```bash
   docker images | grep real-estate
   ```
   You should see:
   ```
   real-estate-backend    latest    ...
   real-estate-frontend   latest    ...
   ```

### Option B: Push to Docker Registry (If deploying to remote EC2)

If your EC2 is on a different machine, you need to push images to a registry:

1. **Tag images for your registry**:
   ```bash
   docker tag real-estate-backend:latest bhav760/real-estate-backend:latest
   docker tag real-estate-frontend:latest bhav760/real-estate-frontend:latest
   ```

2. **Push to registry**:
   ```bash
   docker push bhav760/real-estate-backend:latest
   docker push bhav760/real-estate-frontend:latest
   ```

3. **Update .env.production**:
   ```bash
   BACKEND_IMAGE=bhav760/real-estate-backend:latest
   FRONTEND_IMAGE=bhav760/real-estate-frontend:latest
   ```

### ✅ Completion Check:
- [ ] Backend image built successfully
- [ ] Frontend image built successfully
- [ ] Images visible in `docker images` output
- [ ] (If using registry) Images pushed to registry
- [ ] (If using registry) .env.production updated with registry paths

**Once complete, proceed to Step 4 below.**

---

## 📦 Step 4: Test Locally (Optional but Recommended - 10 minutes)

**Location**: Your local Windows machine (WSL terminal)

Before deploying to EC2, test everything works locally:

1. **Navigate to docker-project**:
   ```bash
   cd /mnt/c/Users/BhavPrakashSingh/Documents/CA3S/CA3S/real-state/docker-project
   ```

2. **Validate docker-compose configuration**:
   ```bash
   docker compose --env-file .env.production config
   ```
   This should show your configuration without errors.

3. **Start services locally** (without SSL):
   ```bash
   # Comment out SSL lines in nginx/conf.d/default.conf temporarily
   # Or use docker-compose-local.yml if you have one
   docker compose --env-file .env.production up -d postgres backend frontend
   ```

4. **Check services are running**:
   ```bash
   docker compose ps
   ```

5. **Test backend**:
   ```bash
   curl http://localhost:5000/health
   ```

6. **Test frontend**:
   ```bash
   curl http://localhost:3000
   ```

7. **Stop services**:
   ```bash
   docker compose down
   ```

### ✅ Completion Check:
- [ ] Configuration validated without errors
- [ ] Services started successfully
- [ ] Backend health check passed
- [ ] Frontend accessible
- [ ] Services stopped cleanly

**Once complete, proceed to Step 5 below.**

---

## 🚀 Step 5: Prepare for EC2 Deployment (5 minutes)

**Location**: Your local Windows machine

### Files to Transfer to EC2:

You need to copy these files to your EC2 instance:

```
docker-project/
├── docker-compose.yml          ⭐ REQUIRED
├── .env.production             ⭐ REQUIRED (with your secrets)
├── nginx/
│   ├── nginx.conf              ⭐ REQUIRED
│   └── conf.d/
│       └── default.conf        ⭐ REQUIRED
├── README.md                   📖 Optional (reference)
└── DEPLOYMENT_GUIDE.md         📖 Optional (reference)
```

### Prepare SCP Commands:

Replace `your-key.pem` and `your-ec2-ip` with your actual values:

```bash
# Set variables (update these)
EC2_KEY="path/to/your-key.pem"
EC2_USER="ec2-user"  # or ubuntu
EC2_IP="your-ec2-ip-address"

# Create directory on EC2
ssh -i $EC2_KEY $EC2_USER@$EC2_IP "mkdir -p ~/real-estate/docker-project/nginx/conf.d"

# Copy files
scp -i $EC2_KEY docker-compose.yml $EC2_USER@$EC2_IP:~/real-estate/docker-project/
scp -i $EC2_KEY .env.production $EC2_USER@$EC2_IP:~/real-estate/docker-project/
scp -i $EC2_KEY nginx/nginx.conf $EC2_USER@$EC2_IP:~/real-estate/docker-project/nginx/
scp -i $EC2_KEY nginx/conf.d/default.conf $EC2_USER@$EC2_IP:~/real-estate/docker-project/nginx/conf.d/
scp -i $EC2_KEY README.md $EC2_USER@$EC2_IP:~/real-estate/docker-project/
scp -i $EC2_KEY DEPLOYMENT_GUIDE.md $EC2_USER@$EC2_IP:~/real-estate/docker-project/
```

### ✅ Completion Check:
- [ ] EC2 SSH key ready
- [ ] EC2 IP address known
- [ ] SCP commands prepared
- [ ] Ready to transfer files

**Once complete, proceed to Step 6 below.**

---

## 🖥️ Step 6: EC2 Server Setup (20 minutes)

**Location**: EC2 instance (SSH)

### 6.1: SSH into EC2

```bash
ssh -i your-key.pem ec2-user@your-ec2-ip
```

### 6.2: Mount EBS Volumes (CRITICAL - DO FIRST)

```bash
# List attached volumes
lsblk

# You should see something like:
# nvme0n1     259:0    0   30G  0 disk /
# nvme1n1     259:1    0   20G  0 disk        ← postgres
# nvme2n1     259:2    0    5G  0 disk        ← certs

# Format volumes (ONLY if new/unused)
sudo mkfs -t ext4 /dev/nvme1n1  # postgres volume
sudo mkfs -t ext4 /dev/nvme2n1  # certs volume

# Create mount directories
sudo mkdir -p /mnt/ebs/postgres
sudo mkdir -p /mnt/ebs/certs
sudo mkdir -p /mnt/ebs/certbot-webroot

# Get UUIDs (save these)
sudo blkid

# Add to /etc/fstab for permanent mounting
sudo nano /etc/fstab

# Add these lines (replace UUIDs with your values from blkid):
UUID=your-postgres-uuid  /mnt/ebs/postgres  ext4  defaults,nofail  0  2
UUID=your-certs-uuid     /mnt/ebs/certs     ext4  defaults,nofail  0  2

# Save: Ctrl+O, Enter, Ctrl+X

# Mount volumes
sudo mount -a

# Verify
df -h | grep /mnt/ebs

# Set permissions
sudo chown -R 999:999 /mnt/ebs/postgres
sudo chmod 755 /mnt/ebs/certs
```

### 6.3: Install Docker

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

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker compose version
```

### 6.4: Install Certbot & Generate SSL Certificate

```bash
# Install Certbot
sudo yum install -y certbot python3-certbot-nginx
# OR for Ubuntu: sudo apt-get install -y certbot python3-certbot-nginx

# Generate certificate (BEFORE starting Docker)
sudo certbot certonly --standalone \
  -d test.plotchoice.com \
  -d www.test.plotchoice.com \
  --email admin@test.plotchoice.com \
  --agree-tos

# Copy to EBS mount
sudo cp -r /etc/letsencrypt/live/test.plotchoice.com /mnt/ebs/certs/live/
sudo cp -r /etc/letsencrypt/archive /mnt/ebs/certs/
sudo chown -R nobody:nobody /mnt/ebs/certs

# Setup auto-renewal
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer

# Verify certificate
ls -la /mnt/ebs/certs/live/test.plotchoice.com/
```

### ✅ Completion Check:
- [ ] SSH access working
- [ ] EBS volumes mounted and verified
- [ ] Docker installed and running
- [ ] SSL certificate generated
- [ ] Certificate copied to EBS
- [ ] Auto-renewal configured

**Once complete, proceed to Step 7 below.**

---

## 📤 Step 7: Transfer Files to EC2 (5 minutes)

**Location**: Your local Windows machine (WSL terminal)

Run the SCP commands you prepared in Step 5:

```bash
# Navigate to docker-project
cd /mnt/c/Users/BhavPrakashSingh/Documents/CA3S/CA3S/real-state/docker-project

# Transfer files (update with your values)
scp -i your-key.pem docker-compose.yml ec2-user@your-ec2-ip:~/real-estate/docker-project/
scp -i your-key.pem .env.production ec2-user@your-ec2-ip:~/real-estate/docker-project/
scp -i your-key.pem nginx/nginx.conf ec2-user@your-ec2-ip:~/real-estate/docker-project/nginx/
scp -i your-key.pem nginx/conf.d/default.conf ec2-user@your-ec2-ip:~/real-estate/docker-project/nginx/conf.d/
```

### Verify on EC2:

```bash
# SSH into EC2
ssh -i your-key.pem ec2-user@your-ec2-ip

# Check files
cd ~/real-estate/docker-project
ls -la

# Should show:
# docker-compose.yml
# .env.production
# nginx/
```

### ✅ Completion Check:
- [ ] All files transferred successfully
- [ ] Files visible on EC2
- [ ] .env.production has correct permissions (600)

**Once complete, proceed to Step 8 below.**

---

## 🚀 Step 8: Deploy Application (10 minutes)

**Location**: EC2 instance (SSH)

### 8.1: Pull Docker Images (if using registry)

```bash
cd ~/real-estate/docker-project

# If images are in a registry, pull them
docker compose --env-file .env.production pull
```

### 8.2: Validate Configuration

```bash
# Check configuration is valid
docker compose --env-file .env.production config

# List services
docker compose --env-file .env.production config --services
```

### 8.3: Start Services

```bash
# Start all services
docker compose --env-file .env.production up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

### Expected Output:

```
NAME                IMAGE                              STATUS
nginx-proxy         nginx:1.25-alpine                  Up (healthy)
postgres-db         postgres:16-alpine                 Up (healthy)
backend-api         real-estate-backend:latest         Up (healthy)
frontend-app        real-estate-frontend:latest        Up (healthy)
```

### ✅ Completion Check:
- [ ] All 4 services showing "Up" status
- [ ] Health checks passing
- [ ] No errors in logs

**Once complete, proceed to Step 9 below.**

---

## ✅ Step 9: Verify Deployment (10 minutes)

**Location**: EC2 instance or your local machine

### 9.1: Check Services

```bash
# On EC2
docker compose ps
docker compose logs --tail=50
```

### 9.2: Test HTTPS Access

```bash
# From your local machine or EC2
curl -I https://test.plotchoice.com
# Should return: HTTP/2 200

# Test API
curl https://test.plotchoice.com/api/health
# Should return: {"status":"ok"} or similar
```

### 9.3: Test in Browser

1. Open browser: https://test.plotchoice.com
2. Check for green padlock (SSL valid)
3. Verify website loads correctly
4. Test login/registration if applicable

### 9.4: Verify Database

```bash
# On EC2
docker compose exec postgres psql -U postgres -d land_marketplace -c "SELECT 1;"
# Should return: 1
```

### 9.5: Check SSL Certificate

```bash
echo | openssl s_client -servername test.plotchoice.com \
  -connect test.plotchoice.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

### ✅ Final Completion Check:
- [ ] All services running and healthy
- [ ] HTTPS working (green padlock)
- [ ] Website accessible
- [ ] API responding
- [ ] Database connected
- [ ] SSL certificate valid
- [ ] No errors in logs

---

## 🎉 Deployment Complete!

Your Real Estate application is now live at: **https://test.plotchoice.com**

### Next Steps:

1. **Monitor logs**: `docker compose logs -f`
2. **Set up backups**: See DEPLOYMENT_GUIDE.md for backup procedures
3. **Configure monitoring**: Set up alerts for service health
4. **Regular maintenance**: Weekly updates and monthly security patches

### Quick Commands Reference:

```bash
# View status
docker compose ps

# View logs
docker compose logs -f [service-name]

# Restart service
docker compose restart [service-name]

# Stop all
docker compose down

# Start all
docker compose up -d

# Update images
docker compose pull
docker compose up -d
```

### Need Help?

- **Troubleshooting**: See DEPLOYMENT_GUIDE.md
- **Maintenance**: See README.md
- **Issues**: Check logs with `docker compose logs`

---

**Congratulations! 🚀 Your deployment is complete!**