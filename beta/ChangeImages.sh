#!/bin/bash
#
# Author: skipper
# Created: 2025-04-03

# Exit script on error
set -e

# Color code definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Version format validation function
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Version must be in major.minor.patch format (e.g., 10.2.7)${NC}"
        return 1
    fi
    return 0
}

# Image update check function
check_image_update() {
    local pull_output=$1
    if echo "$pull_output" | grep -q "Downloaded newer image\|Pull complete"; then
        return 0
    fi
    return 1
}

# Image download function
download_image() {
    local image_name=$1
    local version=$2
    
    echo -e "${YELLOW}Checking $image_name:$version image...${NC}"
    echo
    
    # Save image ID before docker pull
    local before_id
    before_id=$(docker images -q harbor.chequer.io/querypie/$image_name:$version 2>/dev/null || echo "")
    
    # Execute docker pull directly to show progress
    if ! docker pull harbor.chequer.io/querypie/$image_name:$version; then
        return 1
    fi
    
    # Check image ID after docker pull
    local after_id
    after_id=$(docker images -q harbor.chequer.io/querypie/$image_name:$version)
    
    # Change NEEDS_RESTART value only for querypie image
    if [ "$image_name" = "querypie" ]; then
        # Consider it a new image if ID is different or image didn't exist before
        if [ "$before_id" != "$after_id" ] || [ -z "$before_id" ]; then
            NEEDS_RESTART=true
            echo -e "${GREEN}New image has been downloaded.${NC}"
        fi
    fi
    
    return 0
}

# Version and option argument check
if [ $# -lt 1 ]; then
    echo -e "${RED}Please provide a version as an argument.${NC}"
    echo "Usage: $0 <version> [--with-tools] [--force-restart]"
    echo "  version: major.minor.patch format (e.g., 10.2.7)"
    echo "  --with-tools: Also update querypie-tools image"
    echo "  --force-restart: Restart service regardless of image update status"
    exit 1
fi

VERSION=$1
shift  # Remove first argument (version)

# Version format validation
if ! validate_version "$VERSION"; then
    exit 1
fi

UPDATE_TOOLS=false
NEEDS_RESTART=false
FORCE_RESTART=false

# Option check
while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-tools)
            UPDATE_TOOLS=true
            echo -e "${YELLOW}Will also update querypie-tools image.${NC}"
            shift
            ;;
        --force-restart)
            FORCE_RESTART=true
            echo -e "${YELLOW}Service force restart is enabled.${NC}"
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option '$1'${NC}"
            echo "Usage: $0 <version> [--with-tools] [--force-restart]"
            exit 1
            ;;
    esac
done

# Save current directory
ORIGINAL_DIR=$(pwd)

# Set target directory path
TARGET_DIR="./querypie/$VERSION"

# Check if target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: Directory $TARGET_DIR does not exist.${NC}"
    exit 1
fi

# Check if compose-env file exists
if [ ! -f "$TARGET_DIR/compose-env" ]; then
    echo -e "${RED}Error: File $TARGET_DIR/compose-env does not exist.${NC}"
    exit 1
fi

echo -e "${GREEN}All required directories and files exist. Proceeding...${NC}"

# Move to target directory
cd "$TARGET_DIR"

# Download querypie image
if ! download_image "querypie" "$VERSION"; then
    echo -e "${RED}Failed to download querypie image${NC}"
    echo -e "${YELLOW}Skipping service restart. Existing service will continue running.${NC}"
    cd "$ORIGINAL_DIR"
    exit 1
fi

# Update querypie-tools image (only if option is enabled)
if [ "$UPDATE_TOOLS" = true ]; then
    if ! download_image "querypie-tools" "$VERSION"; then
        echo -e "${RED}Failed to download querypie-tools image${NC}"
        echo -e "${YELLOW}Skipping service restart. Existing service will continue running.${NC}"
        cd "$ORIGINAL_DIR"
        exit 1
    fi
fi

if [ "$NEEDS_RESTART" = true ] || [ "$FORCE_RESTART" = true ]; then
    if [ "$FORCE_RESTART" = true ]; then
        echo -e "${YELLOW}Force restart option is enabled. Restarting service.${NC}"
    else
        echo -e "${GREEN}New image has been downloaded. Restarting service.${NC}"
    fi
    
    echo -e "${YELLOW}Restarting QueryPie service...${NC}"
    docker-compose --env-file compose-env --profile querypie down

    # Clean up dangling images
    echo -e "${YELLOW}Cleaning up unused images...${NC}"
    docker image prune -f

    docker-compose --env-file compose-env --profile querypie up -d

    echo -e "${GREEN}Service has started. Checking logs...${NC}"
    docker logs -f querypie-app-1 &
    LOGS_PID=$!

    # Wait for log process to start
    sleep 2

    # Set Ctrl+C signal handler
    trap 'kill $LOGS_PID 2>/dev/null || true; cd "$ORIGINAL_DIR"; exit' INT TERM

    # Wait for log process to finish
    wait $LOGS_PID || true
else
    echo -e "${GREEN}querypie image is already up to date. No service restart needed.${NC}"
fi

# Return to original directory
cd "$ORIGINAL_DIR"

echo -e "${GREEN}All operations completed.${NC}"
