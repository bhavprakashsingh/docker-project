#!/bin/bash

###############################################################################
# Certbot & SSL Certificate Setup Script for Let's Encrypt
# Purpose: Install Certbot, generate SSL certificates, and enable auto-renewal
# Usage: sudo bash setup-certbot.sh <domain> <email>
# Example: sudo bash setup-certbot.sh test.plotchoice.com admin@example.com
###############################################################################

set -e  # Exit on first error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}❌ Missing required arguments${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  sudo bash setup-certbot.sh <domain> <email>"
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo "  sudo bash setup-certbot.sh test.plotchoice.com admin@example.com"
    echo ""
    exit 1
fi

DOMAIN=$1
EMAIL=$2
CERT_PATH="/mnt/ebs/certs"

echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}Certbot & SSL Certificate Setup${NC}"
echo -e "${YELLOW}============================================${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root (sudo)${NC}"
    exit 1
fi

# Create certificate directory on EBS
echo -e "\n${YELLOW}[1/6] Creating certificate directory...${NC}"
mkdir -p "$CERT_PATH"
chmod 755 "$CERT_PATH"
echo -e "${GREEN}✅ Certificate directory: $CERT_PATH${NC}"

# Update system
echo -e "\n${YELLOW}[2/6] Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

# Install Certbot
echo -e "\n${YELLOW}[3/6] Installing Certbot...${NC}"
apt-get install -y certbot python3-certbot-nginx

# Verify Certbot installation
CERTBOT_VERSION=$(certbot --version)
echo -e "${GREEN}✅ $CERTBOT_VERSION${NC}"

# Generate SSL certificate
echo -e "\n${YELLOW}[4/6] Generating SSL certificate for $DOMAIN...${NC}"
echo -e "${BLUE}📝 This may take 1-2 minutes${NC}"

certbot certonly \
    --standalone \
    --agree-tos \
    --no-eff-email \
    --email "$EMAIL" \
    -d "$DOMAIN" \
    --cert-path "$CERT_PATH"

if [ -f "$CERT_PATH/live/$DOMAIN/fullchain.pem" ]; then
    echo -e "${GREEN}✅ SSL certificate generated successfully${NC}"
    echo -e "  • Certificate: $CERT_PATH/live/$DOMAIN/fullchain.pem"
    echo -e "  • Private Key: $CERT_PATH/live/$DOMAIN/privkey.pem"
else
    echo -e "${RED}❌ Certificate generation failed${NC}"
    exit 1
fi

# Configure auto-renewal
echo -e "\n${YELLOW}[5/6] Configuring auto-renewal...${NC}"

# Enable certbot timer
systemctl enable certbot-renew.timer
systemctl start certbot-renew.timer

# Verify timer is active
if systemctl is-active --quiet certbot-renew.timer; then
    echo -e "${GREEN}✅ Certbot auto-renewal timer is active${NC}"
else
    echo -e "${RED}❌ Certbot auto-renewal timer failed to start${NC}"
    exit 1
fi

# Test auto-renewal
echo -e "\n${YELLOW}[6/6] Testing certificate auto-renewal (dry-run)...${NC}"
certbot renew --dry-run --quiet

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Auto-renewal test passed${NC}"
else
    echo -e "${YELLOW}⚠️  Auto-renewal test had warnings (this may be normal)${NC}"
fi

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}✅ Certbot setup completed successfully!${NC}"
echo -e "${GREEN}============================================${NC}"

echo -e "\n${YELLOW}Certificate Information:${NC}"
certbot certificates

echo -e "\n${YELLOW}Auto-Renewal Status:${NC}"
systemctl status certbot-renew.timer --no-pager | head -10

echo -e "\n${YELLOW}Certificate Expiration Details:${NC}"
openssl x509 -in "$CERT_PATH/live/$DOMAIN/fullchain.pem" -noout -dates

echo -e "\n${YELLOW}📝 Important Information:${NC}"
echo "  • Certificate Path: $CERT_PATH/live/$DOMAIN/"
echo "  • Certbot will auto-renew 30 days before expiration"
echo "  • Renewal happens daily via systemd timer"
echo "  • Renewal log: journalctl -u certbot-renew.timer"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "  1. Update nginx/conf.d/default.conf with certificate paths"
echo "  2. Update .env.production with DOMAIN=$DOMAIN"
echo "  3. Verify certificate paths in docker-compose.yml"
echo "  4. Test SSL: curl https://$DOMAIN"
echo ""

# Display next steps
echo -e "${YELLOW}Update nginx/conf.d/default.conf:${NC}"
echo "  ssl_certificate $CERT_PATH/live/$DOMAIN/fullchain.pem;"
echo "  ssl_certificate_key $CERT_PATH/live/$DOMAIN/privkey.pem;"
echo ""
