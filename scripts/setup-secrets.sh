#!/bin/bash

###############################################################################
# Generate Secure Secrets for EC2 Deployment
# Purpose: Create strong random secrets for passwords, API keys, and secrets
# Usage: bash setup-secrets.sh
#
# Generates and displays secrets to add to .env.production
###############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${MAGENTA}╔════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  Secure Secret Generation Tool         ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════╝${NC}"

echo ""
echo -e "${YELLOW}This script generates secure random secrets for your .env.production file${NC}"
echo ""

# Function to generate random string
generate_secret() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d '\n'
}

# Function to generate password
generate_password() {
    local length=${1:-16}
    openssl rand -base64 $length | tr -d '\n' | head -c $length
}

# Function to generate random UUID
generate_uuid() {
    python3 -c "import uuid; print(uuid.uuid4())"
}

echo -e "${YELLOW}Generating secure secrets...${NC}"
echo ""

# Generate all secrets
POSTGRES_PASSWORD=$(generate_password 24)
JWT_ACCESS_SECRET=$(generate_secret 32)
JWT_REFRESH_SECRET=$(generate_secret 32)
ENCRYPTION_KEY=$(generate_secret 32)
ADMIN_EMAIL_SALT=$(generate_secret 16)

echo -e "${GREEN}✅ Secrets generated${NC}"
echo ""

# Display secrets in a copyable format
echo -e "${YELLOW}════════════════════════════════════════${NC}"
echo -e "${YELLOW}Add these to your .env.production file:${NC}"
echo -e "${YELLOW}════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}# PostgreSQL Credentials${NC}"
echo "POSTGRES_USER=postgres"
echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
echo "POSTGRES_DB=land_marketplace"
echo ""

echo -e "${BLUE}# JWT Secrets (for authentication)${NC}"
echo "JWT_ACCESS_SECRET=$JWT_ACCESS_SECRET"
echo "JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET"
echo "JWT_ACCESS_EXPIRES=15m"
echo "JWT_REFRESH_EXPIRES=7d"
echo ""

echo -e "${BLUE}# Encryption${NC}"
echo "ENCRYPTION_KEY=$ENCRYPTION_KEY"
echo ""

echo -e "${BLUE}# Email Configuration${NC}"
echo "RESEND_API_KEY=re_your_resend_api_key_here"
echo "EMAIL_FROM=noreply@your-domain.com"
echo "EMAIL_FROM_NAME=LandMarket"
echo "ADMIN_EMAIL=admin@your-domain.com"
echo "ADMIN_ALERT_EMAIL=alerts@your-domain.com"
echo ""

echo -e "${BLUE}# AWS S3 Configuration (optional)${NC}"
echo "AWS_ACCESS_KEY_ID=your_aws_access_key"
echo "AWS_SECRET_ACCESS_KEY=your_aws_secret_key"
echo "AWS_REGION=ap-south-1"
echo "S3_DOCS_BUCKET=your-bucket-name"
echo "S3_MEDIA_BUCKET=your-bucket-name"
echo "CLOUDFRONT_URL=https://d123456.cloudfront.net"
echo ""

echo -e "${BLUE}# Backend Image${NC}"
echo "BACKEND_IMAGE=your-registry/real-estate-backend:latest"
echo ""

echo -e "${BLUE}# Frontend Image${NC}"
echo "FRONTEND_IMAGE=your-registry/real-estate-frontend:latest"
echo ""

echo -e "${BLUE}# Domain & Deployment${NC}"
echo "DOMAIN=test.plotchoice.com"
echo "NODE_ENV=production"
echo ""

echo -e "${YELLOW}════════════════════════════════════════${NC}"
echo ""

# Option to save to file
read -p "Save secrets to .env.production.secrets.txt? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SECRETS_FILE=".env.production.secrets.txt"
    
    cat > "$SECRETS_FILE" << EOF
# Auto-generated Secrets - $(date)
# ⚠️ PROTECT THIS FILE - Contains sensitive credentials
# ⚠️ Do not commit to version control
# ⚠️ Store in secure location

# PostgreSQL Credentials
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=land_marketplace

# JWT Secrets (for authentication)
JWT_ACCESS_SECRET=$JWT_ACCESS_SECRET
JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET
JWT_ACCESS_EXPIRES=15m
JWT_REFRESH_EXPIRES=7d

# Encryption
ENCRYPTION_KEY=$ENCRYPTION_KEY

# Email Configuration (update these)
RESEND_API_KEY=re_your_resend_api_key_here
EMAIL_FROM=noreply@your-domain.com
EMAIL_FROM_NAME=LandMarket
ADMIN_EMAIL=admin@your-domain.com
ADMIN_ALERT_EMAIL=alerts@your-domain.com

# AWS S3 Configuration (optional - update if using)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=ap-south-1
S3_DOCS_BUCKET=your-bucket-name
S3_MEDIA_BUCKET=your-bucket-name
CLOUDFRONT_URL=https://d123456.cloudfront.net

# Backend & Frontend Images
BACKEND_IMAGE=your-registry/real-estate-backend:latest
FRONTEND_IMAGE=your-registry/real-estate-frontend:latest

# Deployment Configuration
DOMAIN=test.plotchoice.com
NODE_ENV=production
AGENT_LISTING_LIMIT=10
EOF
    
    chmod 600 "$SECRETS_FILE"
    echo -e "${GREEN}✅ Secrets saved to $SECRETS_FILE${NC}"
    echo -e "${YELLOW}⚠️  File permissions set to 600 (read-only by owner)${NC}"
    echo ""
fi

# Security notes
echo -e "${YELLOW}════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔐 Security Best Practices:${NC}"
echo -e "${YELLOW}════════════════════════════════════════${NC}"
echo ""
echo "1. ⚠️  NEVER commit .env.production to version control"
echo "   - Add to .gitignore: .env.production"
echo ""
echo "2. ⚠️  Store these secrets securely:"
echo "   - Use a password manager (1Password, LastPass, Dashlane)"
echo "   - Or keep encrypted backup in secure location"
echo "   - Or use AWS Secrets Manager for production"
echo ""
echo "3. 🔄 Rotate secrets regularly:"
echo "   - Change POSTGRES_PASSWORD quarterly"
echo "   - Regenerate JWT secrets when compromised"
echo "   - Update API keys periodically"
echo ""
echo "4. 🔒 Protect secret files:"
echo "   - Set file permissions to 600 (owner read/write only)"
echo "   - Use SSH key authentication for EC2"
echo "   - Don't share EC2 SSH keys in email or chat"
echo ""
echo "5. 📋 Keep inventory:"
echo "   - Document which secrets are for which service"
echo "   - Track secret expiration dates"
echo "   - Know who has access to each secret"
echo ""

echo -e "${YELLOW}════════════════════════════════════════${NC}"
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo -e "${YELLOW}════════════════════════════════════════${NC}"
echo ""
echo "1. Copy the secrets above"
echo "2. Create .env.production on your local machine (outside git repo)"
echo "3. Paste secrets and update with your actual API keys"
echo "4. Update RESEND_API_KEY, AWS keys, domain, etc."
echo "5. Copy .env.production to EC2 via scp:"
echo "   ${BLUE}scp -i your-key.pem .env.production ec2-user@your-ec2-ip:~/app/.env.production${NC}"
echo ""
