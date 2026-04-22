#!/bin/bash

###############################################################################
# Fix Port 80 Issue - Find and Stop Service Using Port 80
# Purpose: Identify what's using port 80 and help stop it
# Usage: sudo bash fix-port80.sh
###############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root (sudo)${NC}"
    exit 1
fi

echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Port 80 Troubleshooter                ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
echo ""

# Install net-tools if not present (for netstat)
if ! command -v netstat &> /dev/null; then
    echo -e "${YELLOW}Installing net-tools...${NC}"
    apt-get install -y net-tools > /dev/null 2>&1
    echo -e "${GREEN}✅ net-tools installed${NC}"
    echo ""
fi

# Check what's using port 80
echo -e "${YELLOW}Checking port 80...${NC}"
echo ""

PORT_80_PROCESS=$(lsof -i :80 -t 2>/dev/null || true)

if [ -z "$PORT_80_PROCESS" ]; then
    echo -e "${GREEN}✅ Port 80 is available!${NC}"
    echo ""
    echo "You can now run:"
    echo "  ${BLUE}sudo bash scripts/setup-all.sh test.plotchoice.com your-email@example.com${NC}"
    exit 0
fi

# Port 80 is in use - show details
echo -e "${RED}❌ Port 80 is in use${NC}"
echo ""
echo -e "${YELLOW}Process details:${NC}"
lsof -i :80 | head -10

echo ""
echo -e "${YELLOW}Common services that use port 80:${NC}"
echo ""

# Check for common web servers
if systemctl is-active --quiet apache2 2>/dev/null; then
    echo -e "${RED}  • Apache2 is running${NC}"
    APACHE_RUNNING=true
fi

if systemctl is-active --quiet nginx 2>/dev/null; then
    echo -e "${RED}  • Nginx is running${NC}"
    NGINX_RUNNING=true
fi

if systemctl is-active --quiet httpd 2>/dev/null; then
    echo -e "${RED}  • httpd is running${NC}"
    HTTPD_RUNNING=true
fi

if docker ps --format '{{.Names}}' | grep -q nginx 2>/dev/null; then
    echo -e "${RED}  • Docker nginx container is running${NC}"
    DOCKER_NGINX_RUNNING=true
fi

echo ""
echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Recommended Actions                   ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
echo ""

# Provide specific commands to stop services
if [ "$APACHE_RUNNING" = true ]; then
    echo -e "${YELLOW}Stop Apache2:${NC}"
    echo "  ${BLUE}sudo systemctl stop apache2${NC}"
    echo "  ${BLUE}sudo systemctl disable apache2${NC}"
    echo ""
fi

if [ "$NGINX_RUNNING" = true ]; then
    echo -e "${YELLOW}Stop Nginx:${NC}"
    echo "  ${BLUE}sudo systemctl stop nginx${NC}"
    echo "  ${BLUE}sudo systemctl disable nginx${NC}"
    echo ""
fi

if [ "$HTTPD_RUNNING" = true ]; then
    echo -e "${YELLOW}Stop httpd:${NC}"
    echo "  ${BLUE}sudo systemctl stop httpd${NC}"
    echo "  ${BLUE}sudo systemctl disable httpd${NC}"
    echo ""
fi

if [ "$DOCKER_NGINX_RUNNING" = true ]; then
    echo -e "${YELLOW}Stop Docker nginx:${NC}"
    echo "  ${BLUE}docker compose down${NC}"
    echo ""
fi

# Offer to stop services automatically
echo ""
read -p "Would you like me to stop these services automatically? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Stopping services...${NC}"
    
    if [ "$APACHE_RUNNING" = true ]; then
        systemctl stop apache2
        systemctl disable apache2
        echo -e "${GREEN}✅ Apache2 stopped and disabled${NC}"
    fi
    
    if [ "$NGINX_RUNNING" = true ]; then
        systemctl stop nginx
        systemctl disable nginx
        echo -e "${GREEN}✅ Nginx stopped and disabled${NC}"
    fi
    
    if [ "$HTTPD_RUNNING" = true ]; then
        systemctl stop httpd
        systemctl disable httpd
        echo -e "${GREEN}✅ httpd stopped and disabled${NC}"
    fi
    
    if [ "$DOCKER_NGINX_RUNNING" = true ]; then
        docker compose down 2>/dev/null || true
        echo -e "${GREEN}✅ Docker containers stopped${NC}"
    fi
    
    # Wait a moment for ports to be released
    sleep 2
    
    # Check again
    echo ""
    echo -e "${YELLOW}Verifying port 80 is now free...${NC}"
    if lsof -i :80 -t &>/dev/null; then
        echo -e "${RED}❌ Port 80 is still in use${NC}"
        echo ""
        echo "Remaining processes:"
        lsof -i :80
        echo ""
        echo "You may need to manually kill these processes:"
        echo "  ${BLUE}sudo kill -9 $(lsof -i :80 -t)${NC}"
    else
        echo -e "${GREEN}✅ Port 80 is now available!${NC}"
        echo ""
        echo "You can now run:"
        echo "  ${BLUE}sudo bash scripts/setup-all.sh test.plotchoice.com your-email@example.com${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}Please manually stop the services using port 80, then run:${NC}"
    echo "  ${BLUE}sudo bash scripts/setup-all.sh test.plotchoice.com your-email@example.com${NC}"
fi

echo ""

# Made with Bob
