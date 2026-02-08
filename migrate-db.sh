#!/bin/bash

# SQLite Database Migration Script for Code-Canvas
# Migrates local taskManagement.db to Docker volume

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOCAL_DB="./taskManagement.db"
CONTAINER_NAME="code-canvas-db"
APP_CONTAINER="code-canvas-app"
VOLUME_PATH="/data/taskManagement.db"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Code-Canvas Database Migration Tool  ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check if local database exists
echo -e "${YELLOW}[1/6]${NC} Checking for local database..."
if [ ! -f "$LOCAL_DB" ]; then
    echo -e "${RED}Error: Local database '$LOCAL_DB' not found.${NC}"
    echo "Make sure you're running this script from the project root directory."
    exit 1
fi

DB_SIZE=$(du -h "$LOCAL_DB" | cut -f1)
echo -e "${GREEN}Found local database ($DB_SIZE)${NC}"
echo ""

# Step 2: Check if Docker is running
echo -e "${YELLOW}[2/6]${NC} Checking Docker status..."
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi
echo -e "${GREEN}Docker is running${NC}"
echo ""

# Step 3: Build and start containers if not running
echo -e "${YELLOW}[3/6]${NC} Starting Docker containers..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Building and starting containers..."
    docker-compose up -d --build
    echo "Waiting for containers to be ready..."
    sleep 5
else
    echo "Containers already running"
fi
echo -e "${GREEN}Containers are up${NC}"
echo ""

# Step 4: Copy database to volume
echo -e "${YELLOW}[4/6]${NC} Copying database to Docker volume..."
docker cp "$LOCAL_DB" "${CONTAINER_NAME}:${VOLUME_PATH}"
echo -e "${GREEN}Database copied successfully${NC}"
echo ""

# Step 5: Fix permissions
echo -e "${YELLOW}[5/6]${NC} Setting correct permissions..."
docker exec -u root "$CONTAINER_NAME" chown dbuser:dbgroup "$VOLUME_PATH"
docker exec -u root "$CONTAINER_NAME" chmod 644 "$VOLUME_PATH"
echo -e "${GREEN}Permissions set${NC}"
echo ""

# Step 6: Restart app container
echo -e "${YELLOW}[6/6]${NC} Restarting application container..."
docker-compose restart code-canvas
echo "Waiting for app to be ready..."
sleep 5
echo -e "${GREEN}Application restarted${NC}"
echo ""

# Verify migration
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verifying Migration                  ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if database exists in volume
if docker exec "$CONTAINER_NAME" test -f "$VOLUME_PATH"; then
    DOCKER_DB_SIZE=$(docker exec "$CONTAINER_NAME" du -h "$VOLUME_PATH" | cut -f1)
    echo -e "${GREEN}Database exists in volume ($DOCKER_DB_SIZE)${NC}"
else
    echo -e "${RED}Warning: Database not found in volume${NC}"
    exit 1
fi

# Check app health
echo "Checking application health..."
sleep 2
if curl -s --fail http://localhost:3000 > /dev/null 2>&1; then
    echo -e "${GREEN}Application is responding on http://localhost:3000${NC}"
else
    echo -e "${YELLOW}Warning: Could not reach application. It may still be starting up.${NC}"
    echo "Try: curl http://localhost:3000"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  Migration Complete!                  ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Your data has been migrated to the Docker volume."
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Verify your app is working: open http://localhost:3000"
echo "2. Check your data is intact in the application"
echo ""
read -p "Would you like to backup and remove the local database? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    BACKUP_NAME="taskManagement.db.backup.$(date +%Y%m%d_%H%M%S)"
    mv "$LOCAL_DB" "$BACKUP_NAME"
    echo -e "${GREEN}Local database backed up to: $BACKUP_NAME${NC}"
    echo ""
    echo "You can delete this backup once you've confirmed everything works:"
    echo "  rm $BACKUP_NAME"
else
    echo ""
    echo "Local database kept at: $LOCAL_DB"
    echo "You can manually remove it later with:"
    echo "  rm $LOCAL_DB"
fi

echo ""
echo -e "${GREEN}Done!${NC}"
