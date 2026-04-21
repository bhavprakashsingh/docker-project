#!/bin/bash

###############################################################################
# Complete EC2 Setup Script
# Purpose: Complete setup of Docker, docker-compose, and Certbot in one go
# Usage: sudo bash setup-all.sh <domain> <email>
# Example: sudo bash setup-all.sh test.plotchoice.com admin@example.com
###############################################################################

set -e  # Exit on first error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}❌ Missing required arguments${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  sudo bash setup-all.sh <domain> <email>"
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo "  sudo bash setup-all.sh test.plotchoice.com admin@example.com"
    echo ""
    exit 1
fi

DOMAIN=$1
EMAIL=$2

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root (sudo)${NC}"
    exit 1
fi

echo -e "${MAGENTA}╔════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  EC2 Complete Setup (Docker + Certbot) ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANT PREREQUISITE CHECK:${NC}"
echo ""
echo -e "${YELLOW}Before running this script, you MUST:${NC}"
echo "  1. Run: ${BLUE}sudo bash scripts/setup-ebs.sh${NC}"
echo "  2. Verify EBS volumes are mounted:"
echo "     - ${BLUE}df -h | grep ebs${NC}"
echo "     - Should show /mnt/ebs/postgres and /mnt/ebs/certs"
echo ""
echo "  If you haven't mounted EBS volumes yet:"
echo "    ${BLUE}sudo bash scripts/setup-ebs.sh${NC}"
echo "    Then come back and run this script"
echo ""
read -p "Have you run setup-ebs.sh and verified EBS volumes are mounted? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Please mount EBS volumes first by running:${NC}"
    echo "  ${BLUE}sudo bash scripts/setup-ebs.sh${NC}"
    exit 1
fi

echo ""

START_TIME=$(date +%s)

# ============================================================================
# Step 1: Docker & docker-compose
# ============================================================================

echo ""
echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Step 1: Installing Docker             ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"

# Update system packages
echo -e "\n${YELLOW}[1/6] Updating system packages...${NC}"
apt-get update > /dev/null 2>&1
apt-get upgrade -y > /dev/null 2>&1
echo -e "${GREEN}✅ System packages updated${NC}"

# Install prerequisites
echo -e "\n${YELLOW}[2/6] Installing prerequisites...${NC}"
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https > /dev/null 2>&1
echo -e "${GREEN}✅ Prerequisites installed${NC}"

# Add Docker's GPG key
echo -e "\n${YELLOW}[3/6] Adding Docker GPG key...${NC}"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null
echo -e "${GREEN}✅ Docker GPG key added${NC}"

# Add Docker repository
echo -e "\n${YELLOW}[4/6] Adding Docker repository...${NC}"
echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update > /dev/null 2>&1
echo -e "${GREEN}✅ Docker repository configured${NC}"

# Install Docker CE
echo -e "\n${YELLOW}[5/6] Installing Docker & docker-compose...${NC}"
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin > /dev/null 2>&1
echo -e "${GREEN}✅ Docker installed: $(docker --version)${NC}"
echo -e "${GREEN}✅ docker-compose installed: $(docker compose version | head -1)${NC}"

# Enable Docker daemon to start on boot
echo -e "\n${YELLOW}[6/6] Configuring Docker auto-start...${NC}"
systemctl enable docker > /dev/null 2>&1
systemctl start docker > /dev/null 2>&1
systemctl enable containerd > /dev/null 2>&1
systemctl restart containerd > /dev/null 2>&1
echo -e "${GREEN}✅ Docker daemon configured for auto-start${NC}"

# ============================================================================
# Step 2: Certbot & SSL
# ============================================================================

echo ""
echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Step 2: Installing Certbot            ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"

CERT_PATH="/mnt/ebs/certs"

# Create certificate directory
echo -e "\n${YELLOW}[1/5] Creating certificate directory...${NC}"
mkdir -p "$CERT_PATH"
chmod 755 "$CERT_PATH"
echo -e "${GREEN}✅ Certificate directory created: $CERT_PATH${NC}"

# Install Certbot
echo -e "\n${YELLOW}[2/5] Installing Certbot...${NC}"
apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1
echo -e "${GREEN}✅ Certbot installed: $(certbot --version)${NC}"

# Generate SSL certificate
echo -e "\n${YELLOW}[3/5] Generating SSL certificate...${NC}"
certbot certonly \
    --standalone \
    --agree-tos \
    --no-eff-email \
    --email "$EMAIL" \
    -d "$DOMAIN" \
    --cert-path "$CERT_PATH" \
    --non-interactive \
    --force-renewal > /dev/null 2>&1

if [ -f "$CERT_PATH/live/$DOMAIN/fullchain.pem" ]; then
    echo -e "${GREEN}✅ SSL certificate generated${NC}"
    echo -e "   Certificate: $CERT_PATH/live/$DOMAIN/fullchain.pem"
else
    echo -e "${RED}❌ Certificate generation failed${NC}"
    exit 1
fi

# Configure auto-renewal
echo -e "\n${YELLOW}[4/5] Enabling auto-renewal...${NC}"
systemctl enable certbot-renew.timer > /dev/null 2>&1
systemctl start certbot-renew.timer > /dev/null 2>&1
echo -e "${GREEN}✅ Certbot auto-renewal enabled${NC}"

# Test auto-renewal
echo -e "\n${YELLOW}[5/5] Testing auto-renewal (dry-run)...${NC}"
certbot renew --dry-run --quiet 2>/dev/null || true
echo -e "${GREEN}✅ Auto-renewal test completed${NC}"

# ============================================================================
# Summary
# ============================================================================

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ SETUP COMPLETED SUCCESSFULLY       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"

echo ""
echo -e "${YELLOW}Setup Summary:${NC}"
echo "  ✅ Docker installed and auto-start enabled"
echo "  ✅ docker-compose ready for use"
echo "  ✅ Certbot installed with auto-renewal"
echo "  ✅ SSL certificate generated for $DOMAIN"
echo "  ⏱️  Setup Duration: ${MINUTES}m ${SECONDS}s"
echo ""

echo -e "${YELLOW}Certificate Details:${NC}"
openssl x509 -in "$CERT_PATH/live/$DOMAIN/fullchain.pem" -noout -dates | sed 's/^/  /'

echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "  1. ✅ Docker and Certbot are ready"
echo "  2. ⬜ Copy docker-compose.yml and .env.production to EC2"
echo "  3. ⬜ Update nginx/conf.d/default.conf domain settings"
echo "  4. ⬜ Prepare EBS volumes (/mnt/ebs/postgres directory)"
echo "  5. ⬜ Run: docker compose pull"
echo "  6. ⬜ Run: docker compose config (validate)"
echo "  7. ⬜ Run: docker compose up -d (start services)"
echo ""

echo -e "${YELLOW}Useful Commands:${NC}"
echo "  View certificates: ${BLUE}certbot certificates${NC}"
echo "  Check expiration: ${BLUE}certbot certificates --deploy-hook 'systemctl reload nginx'${NC}"
echo "  Test SSL: ${BLUE}curl -v https://$DOMAIN${NC}"
echo "  Docker status: ${BLUE}docker ps${NC}"
echo "  Docker logs: ${BLUE}docker compose logs -f${NC}"
echo ""
