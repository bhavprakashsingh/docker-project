#!/bin/bash
set -e

# Setup script for Docker secrets
# This script generates secure random secrets for production deployment

SECRETS_DIR="./secrets"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Production Secrets Setup"
echo "========================================="
echo ""

# Create secrets directory
mkdir -p "${SECRETS_DIR}"

# Function to generate random secret
generate_secret() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Function to create secret file
create_secret_file() {
    local filename=$1
    local filepath="${SECRETS_DIR}/${filename}"
    
    if [ -f "${filepath}" ]; then
        echo -e "${YELLOW}Warning: ${filename} already exists${NC}"
        read -p "Do you want to regenerate it? (yes/no): " REGENERATE
        if [ "${REGENERATE}" != "yes" ]; then
            echo "Skipping ${filename}"
            return
        fi
    fi
    
    local secret=$(generate_secret)
    echo -n "${secret}" > "${filepath}"
    chmod 600 "${filepath}"
    echo -e "${GREEN}✓ Created: ${filename}${NC}"
}

# Generate secrets
echo "Generating secrets..."
echo ""

create_secret_file "postgres_password.txt"
create_secret_file "jwt_access_secret.txt"
create_secret_file "jwt_refresh_secret.txt"

# Create .gitignore in secrets directory
cat > "${SECRETS_DIR}/.gitignore" << 'EOF'
# Ignore all secret files
*.txt

# But keep the README
!README.md
!.gitignore
EOF

echo -e "${GREEN}✓ Created: .gitignore${NC}"

# Create README
cat > "${SECRETS_DIR}/README.md" << 'EOF'
# Docker Secrets Directory

This directory contains sensitive secrets used by Docker Compose.

## Security Notes

- **NEVER** commit actual secret files to version control
- All `.txt` files are ignored by git
- Secrets should have 600 permissions (read/write for owner only)
- Use strong, randomly generated values for all secrets

## Files

- `postgres_password.txt` - PostgreSQL database password
- `jwt_access_secret.txt` - JWT access token secret
- `jwt_refresh_secret.txt` - JWT refresh token secret

## Regenerating Secrets

To regenerate secrets, run:
```bash
./scripts/setup-secrets.sh
```

## Manual Secret Creation

If you need to create secrets manually:
```bash
# Generate a random 32-character secret
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32 > secrets/your_secret.txt
chmod 600 secrets/your_secret.txt
```
EOF

echo -e "${GREEN}✓ Created: README.md${NC}"

echo ""
echo "========================================="
echo -e "${GREEN}Secrets setup completed!${NC}"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Review and update .env.production with your configuration"
echo "2. Configure SSL certificates in nginx/ssl/"
echo "3. Update nginx/conf.d/default.conf with your domain"
echo "4. Review docker-compose.prod.yml configuration"
echo "5. Deploy with: docker-compose -f docker-compose.prod.yml up -d"
echo ""
echo -e "${YELLOW}Important: Keep the secrets/ directory secure and never commit it to version control!${NC}"

# Made with Bob
