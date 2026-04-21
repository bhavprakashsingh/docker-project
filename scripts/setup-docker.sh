#!/bin/bash

###############################################################################
# Docker & docker-compose Installation & Configuration Script
# Purpose: Install Docker, docker-compose, and enable auto-start on EC2
# Usage: sudo bash setup-docker.sh
###############################################################################

set -e  # Exit on first error

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}Docker & docker-compose Setup Script${NC}"
echo -e "${YELLOW}============================================${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root (sudo)${NC}"
    exit 1
fi

# Update system packages
echo -e "\n${YELLOW}[1/6] Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

# Install prerequisites
echo -e "\n${YELLOW}[2/6] Installing prerequisites...${NC}"
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https

# Add Docker's GPG key
echo -e "\n${YELLOW}[3/6] Adding Docker GPG key...${NC}"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo -e "\n${YELLOW}[4/6] Adding Docker repository...${NC}"
echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

# Install Docker CE
echo -e "\n${YELLOW}[5/6] Installing Docker & docker-compose...${NC}"
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin

# Verify Docker installation
DOCKER_VERSION=$(docker --version)
echo -e "${GREEN}✅ $DOCKER_VERSION${NC}"

# Verify docker-compose installation
COMPOSE_VERSION=$(docker compose version)
echo -e "${GREEN}✅ $COMPOSE_VERSION${NC}"

# Enable Docker daemon to start on boot
echo -e "\n${YELLOW}[6/6] Configuring Docker to auto-start on reboot...${NC}"
systemctl enable docker
systemctl start docker

# Verify Docker daemon is running
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✅ Docker daemon is running${NC}"
else
    echo -e "${RED}❌ Docker daemon failed to start${NC}"
    exit 1
fi

# Enable containerd
echo -e "\n${YELLOW}Enabling containerd auto-start...${NC}"
systemctl enable containerd
systemctl restart containerd

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}✅ Docker setup completed successfully!${NC}"
echo -e "${GREEN}============================================${NC}"

echo -e "\n${YELLOW}Summary:${NC}"
echo "  • Docker daemon will auto-start on EC2 reboot"
echo "  • docker-compose is ready to use"
echo "  • Test with: docker ps"
echo ""

# Display Docker info
echo -e "${YELLOW}Docker System Info:${NC}"
docker system df

echo -e "\n${YELLOW}📝 Next Steps:${NC}"
echo "  1. Copy docker-compose.yml to your deployment directory"
echo "  2. Set up your .env.production file"
echo "  3. Run: docker compose config (validate syntax)"
echo "  4. Run: docker compose pull (download images)"
echo "  5. Run: docker compose up -d (start services)"
echo ""
