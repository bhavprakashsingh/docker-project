#!/bin/bash

###############################################################################
# EBS Volume Mounting & fstab Configuration Script
# Purpose: Mount EBS volumes persistently on EC2 instance
# Usage: sudo bash setup-ebs.sh
#
# ⚠️  RUN THIS FIRST before running setup-all.sh, setup-docker.sh, or setup-certbot.sh
###############################################################################

set -e  # Exit on first error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  EBS Volume Mounting & fstab Setup     ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root (sudo)${NC}"
    exit 1
fi

echo -e "\n${BLUE}Prerequisites:${NC}"
echo "  ✅ 2 EBS volumes already attached to EC2 instance"
echo "  ✅ You know which device is which (e.g., /dev/nvme1n1, /dev/nvme2n1)"
echo ""

# List available block devices
echo -e "${YELLOW}Step 1: Identifying EBS volumes...${NC}"
echo ""
echo -e "${BLUE}Available block devices:${NC}"
lsblk -o NAME,SIZE,TYPE,STATE | grep -E "nvme|xvd|sda|sdb" | head -20

echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Identify your 2 EBS volumes above${NC}"
echo "  - Usually named /dev/nvme1n1, /dev/nvme2n1 (or /dev/xvdf, /dev/xvdg older systems)"
echo "  - Size should be 20GB (postgres) and 5GB (certs)"
echo ""

# Get user input for device names
read -p "Enter device name for postgres volume (e.g., /dev/nvme1n1): " POSTGRES_DEVICE
read -p "Enter device name for certs volume (e.g., /dev/nvme2n1): " CERTS_DEVICE

# Validate input
if [ -z "$POSTGRES_DEVICE" ] || [ -z "$CERTS_DEVICE" ]; then
    echo -e "${RED}❌ Device names cannot be empty${NC}"
    exit 1
fi

if [ ! -b "$POSTGRES_DEVICE" ] || [ ! -b "$CERTS_DEVICE" ]; then
    echo -e "${RED}❌ Invalid device names. Devices not found.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Selected Devices:${NC}"
echo "  Postgres: $POSTGRES_DEVICE"
echo "  Certs: $CERTS_DEVICE"
echo ""

read -p "Proceed with mounting? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Mounting cancelled${NC}"
    exit 1
fi

# ============================================================================
# Step 2: Format and Mount Postgres Volume
# ============================================================================

echo ""
echo -e "${YELLOW}Step 2: Setting up postgres volume at /mnt/ebs/postgres...${NC}"

# Check if already formatted
if sudo blkid "$POSTGRES_DEVICE" &>/dev/null; then
    echo -e "${GREEN}✅ Postgres device already has filesystem${NC}"
    POSTGRES_UUID=$(lsblk -no UUID "$POSTGRES_DEVICE")
else
    echo -e "${YELLOW}  Formatting $POSTGRES_DEVICE as ext4...${NC}"
    sudo mkfs.ext4 -F "$POSTGRES_DEVICE" > /dev/null 2>&1
    echo -e "${GREEN}✅ Postgres device formatted${NC}"
    POSTGRES_UUID=$(lsblk -no UUID "$POSTGRES_DEVICE")
fi

# Create mount directory
if [ ! -d /mnt/ebs ]; then
    sudo mkdir -p /mnt/ebs
    echo -e "${GREEN}✅ Created /mnt/ebs directory${NC}"
fi

if [ ! -d /mnt/ebs/postgres ]; then
    sudo mkdir -p /mnt/ebs/postgres
    echo -e "${GREEN}✅ Created /mnt/ebs/postgres directory${NC}"
fi

# Mount the volume
echo -e "${YELLOW}  Mounting postgres volume...${NC}"
sudo mount "$POSTGRES_DEVICE" /mnt/ebs/postgres 2>/dev/null || true

echo -e "${GREEN}✅ Postgres volume mounted${NC}"
echo "  Device: $POSTGRES_DEVICE"
echo "  UUID: $POSTGRES_UUID"
echo "  Mount point: /mnt/ebs/postgres"

# ============================================================================
# Step 3: Format and Mount Certs Volume
# ============================================================================

echo ""
echo -e "${YELLOW}Step 3: Setting up certs volume at /mnt/ebs/certs...${NC}"

# Check if already formatted
if sudo blkid "$CERTS_DEVICE" &>/dev/null; then
    echo -e "${GREEN}✅ Certs device already has filesystem${NC}"
    CERTS_UUID=$(lsblk -no UUID "$CERTS_DEVICE")
else
    echo -e "${YELLOW}  Formatting $CERTS_DEVICE as ext4...${NC}"
    sudo mkfs.ext4 -F "$CERTS_DEVICE" > /dev/null 2>&1
    echo -e "${GREEN}✅ Certs device formatted${NC}"
    CERTS_UUID=$(lsblk -no UUID "$CERTS_DEVICE")
fi

# Create mount directory
if [ ! -d /mnt/ebs/certs ]; then
    sudo mkdir -p /mnt/ebs/certs
    echo -e "${GREEN}✅ Created /mnt/ebs/certs directory${NC}"
fi

# Mount the volume
echo -e "${YELLOW}  Mounting certs volume...${NC}"
sudo mount "$CERTS_DEVICE" /mnt/ebs/certs 2>/dev/null || true

echo -e "${GREEN}✅ Certs volume mounted${NC}"
echo "  Device: $CERTS_DEVICE"
echo "  UUID: $CERTS_UUID"
echo "  Mount point: /mnt/ebs/certs"

# ============================================================================
# Step 4: Configure fstab for Persistent Mounting
# ============================================================================

echo ""
echo -e "${YELLOW}Step 4: Configuring /etc/fstab for persistent mounting...${NC}"

# Backup original fstab
sudo cp /etc/fstab /etc/fstab.backup
echo -e "${GREEN}✅ Backed up /etc/fstab to /etc/fstab.backup${NC}"

# Add postgres mount to fstab if not already present
if ! grep -q "UUID=$POSTGRES_UUID" /etc/fstab; then
    echo "UUID=$POSTGRES_UUID /mnt/ebs/postgres ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab > /dev/null
    echo -e "${GREEN}✅ Added postgres volume to /etc/fstab${NC}"
else
    echo -e "${YELLOW}⚠️  Postgres volume already in /etc/fstab${NC}"
fi

# Add certs mount to fstab if not already present
if ! grep -q "UUID=$CERTS_UUID" /etc/fstab; then
    echo "UUID=$CERTS_UUID /mnt/ebs/certs ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab > /dev/null
    echo -e "${GREEN}✅ Added certs volume to /etc/fstab${NC}"
else
    echo -e "${YELLOW}⚠️  Certs volume already in /etc/fstab${NC}"
fi

# ============================================================================
# Step 5: Verify fstab Configuration
# ============================================================================

echo ""
echo -e "${YELLOW}Step 5: Verifying fstab configuration...${NC}"
sudo mount -a > /dev/null 2>&1
echo -e "${GREEN}✅ fstab verified${NC}"

# ============================================================================
# Step 6: Set Permissions
# ============================================================================

echo ""
echo -e "${YELLOW}Step 6: Setting permissions...${NC}"

sudo chown root:root /mnt/ebs
sudo chmod 755 /mnt/ebs

sudo chown root:root /mnt/ebs/postgres
sudo chmod 755 /mnt/ebs/postgres

sudo chown root:root /mnt/ebs/certs
sudo chmod 755 /mnt/ebs/certs

echo -e "${GREEN}✅ Permissions set${NC}"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ EBS MOUNTING COMPLETE              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"

echo ""
echo -e "${YELLOW}Mounted Volumes:${NC}"
df -h | grep -E "ebs|Mount" | sed 's/^/  /'

echo ""
echo -e "${YELLOW}fstab Entry:${NC}"
grep ebs /etc/fstab | sed 's/^/  /'

echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "  1. ✅ EBS volumes mounted and configured"
echo "  2. ⬜ Run: ${BLUE}sudo bash scripts/setup-all.sh your-domain.com your-email@example.com${NC}"
echo "  3. ⬜ Or run individual setup scripts:"
echo "     - ${BLUE}sudo bash scripts/setup-docker.sh${NC}"
echo "     - ${BLUE}sudo bash scripts/setup-certbot.sh your-domain.com your-email@example.com${NC}"
echo ""

echo -e "${YELLOW}⚠️  Important:${NC}"
echo "  • Volumes will persist after EC2 reboot - fstab configured"
echo "  • Verify mounts: ${BLUE}df -h | grep ebs${NC}"
echo "  • Check fstab: ${BLUE}sudo cat /etc/fstab | grep ebs${NC}"
echo ""
