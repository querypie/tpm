#!/bin/bash
#
# Author: skipper
# Created: 2025-04-03
#

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to validate version format (major.minor.patch)
validate_version() {
    if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Version must be in major.minor.patch format (e.g., 10.2.7)${NC}"
        exit 1
    fi
}

# Function to check if mysql client exists
check_mysql() {
    if ! command -v mysql &> /dev/null; then
        echo -e "${RED}Error: mysql client is not installed.${NC}"
        echo "Please install MySQL client tools and try again."
        echo "You can install it using one of these commands:"
        echo "  - For Ubuntu/Debian: sudo apt-get install mysql-client"
        echo "  - For CentOS/RHEL: sudo yum install mysql"
        echo "  - For macOS: brew install mysql-client"
        exit 1
    fi
}

# Function to get user confirmation
get_confirmation() {
    local message=$1
    local response
    
    echo -e "\n${YELLOW}$message${NC}"
    read -p "Do you want to proceed? (Press Enter or type 'y' to continue): " response
    
    # Convert response to lowercase
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    
    # Continue only if response is empty (Enter) or 'y'
    if [ -z "$response" ] || [ "$response" = "y" ]; then
        return 0
    else
        echo -e "${RED}Operation cancelled by user${NC}"
        exit 1
    fi
}

# Check if version parameter is provided
if [ "$#" -ne 1 ]; then
    echo -e "${RED}Error: Version parameter is required${NC}"
    echo "Usage: $0 <version>"
    echo "Example: $0 10.2.7"
    exit 1
fi

VERSION=$1

# Validate version format
validate_version "$VERSION"

# Check if mysql client is available
check_mysql

# Change directory to version-specific folder
TARGET_DIR="./querypie/$VERSION"
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: Directory $TARGET_DIR does not exist${NC}"
    exit 1
fi

cd "$TARGET_DIR" || exit 1

# Read database connection information from compose-env
if [ ! -f "compose-env" ]; then
    echo -e "${RED}Error: compose-env file not found in $TARGET_DIR${NC}"
    exit 1
fi

# Source the compose-env file to get database credentials
source compose-env

# Convert host.docker.internal to 127.0.0.1
if [ "$DB_HOST" = "host.docker.internal" ]; then
    DB_HOST="127.0.0.1"
    echo "Converting host.docker.internal to 127.0.0.1"
fi

# Check if required variables are set
if [ -z "$DB_HOST" ] || [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: Database connection information is incomplete in compose-env${NC}"
    echo "Please check if these variables are set in compose-env:"
    echo "  DB_HOST=${DB_HOST:-not set}"
    echo "  DB_USERNAME=${DB_USERNAME:-not set}"
    echo "  DB_PASSWORD=${DB_PASSWORD:-not set}"
    exit 1
fi

# Set default port if not specified
DB_PORT=${DB_PORT:-3306}

# Check which backup files exist
QUERYPIE_EXISTS=false
LOG_EXISTS=false
SNAPSHOT_EXISTS=false
FOUND_FILES=0

if [ -f "querypie.sql" ]; then
    QUERYPIE_EXISTS=true
    ((FOUND_FILES++))
fi

if [ -f "querypie_log.sql" ]; then
    LOG_EXISTS=true
    ((FOUND_FILES++))
fi

if [ -f "querypie_snapshot.sql" ]; then
    SNAPSHOT_EXISTS=true
    ((FOUND_FILES++))
fi

# Show status of backup files
echo -e "\n${GREEN}Found backup files:${NC}"
if [ "$QUERYPIE_EXISTS" = true ]; then
    echo -e "✓ querypie.sql $(ls -lh querypie.sql)"
else
    echo -e "${RED}✗ querypie.sql not found${NC}"
fi

if [ "$LOG_EXISTS" = true ]; then
    echo -e "✓ querypie_log.sql $(ls -lh querypie_log.sql)"
else
    echo -e "${RED}✗ querypie_log.sql not found${NC}"
fi

if [ "$SNAPSHOT_EXISTS" = true ]; then
    echo -e "✓ querypie_snapshot.sql $(ls -lh querypie_snapshot.sql)"
else
    echo -e "${RED}✗ querypie_snapshot.sql not found${NC}"
fi

# Get confirmation based on found files
if [ $FOUND_FILES -eq 0 ]; then
    echo -e "\n${RED}Error: No backup files found in $TARGET_DIR${NC}"
    exit 1
elif [ $FOUND_FILES -eq 3 ]; then
    get_confirmation "All backup files found. This will restore all three databases."
else
    get_confirmation "Only $FOUND_FILES backup file(s) found. This will perform a partial restore."
fi

# Initialize completion flags
QUERYPIE_COMPLETED=false
LOG_COMPLETED=false
SNAPSHOT_COMPLETED=false

echo -e "\n${GREEN}Starting database restore processes...${NC}"

# Start restore processes in parallel
if [ "$QUERYPIE_EXISTS" = true ]; then
    (
        RESTORE_CMD="mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'${DB_PASSWORD}' querypie < ./querypie.sql"
        DISPLAY_CMD="mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'hidden' querypie < ./querypie.sql"
        echo "Starting: ${DISPLAY_CMD}"
        ERROR_LOG=$(eval "$RESTORE_CMD" 2>&1)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ querypie database restore completed${NC}"
        else
            echo -e "${RED}✗ Error restoring querypie database:${NC}"
            echo "$ERROR_LOG"
        fi
    ) &
    QUERYPIE_PID=$!
fi

if [ "$LOG_EXISTS" = true ]; then
    (
        RESTORE_CMD="mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'${DB_PASSWORD}' querypie_log < ./querypie_log.sql"
        DISPLAY_CMD="mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'hidden' querypie_log < ./querypie_log.sql"
        echo "Starting: ${DISPLAY_CMD}"
        ERROR_LOG=$(eval "$RESTORE_CMD" 2>&1)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ querypie_log database restore completed${NC}"
        else
            echo -e "${RED}✗ Error restoring querypie_log database:${NC}"
            echo "$ERROR_LOG"
        fi
    ) &
    LOG_PID=$!
fi

if [ "$SNAPSHOT_EXISTS" = true ]; then
    (
        RESTORE_CMD="mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'${DB_PASSWORD}' querypie_snapshot < ./querypie_snapshot.sql"
        DISPLAY_CMD="mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'hidden' querypie_snapshot < ./querypie_snapshot.sql"
        echo "Starting: ${DISPLAY_CMD}"
        ERROR_LOG=$(eval "$RESTORE_CMD" 2>&1)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ querypie_snapshot database restore completed${NC}"
        else
            echo -e "${RED}✗ Error restoring querypie_snapshot database:${NC}"
            echo "$ERROR_LOG"
        fi
    ) &
    SNAPSHOT_PID=$!
fi

# Wait for all processes to complete
RESTORE_SUCCESS=true

if [ "$QUERYPIE_EXISTS" = true ]; then
    wait $QUERYPIE_PID
    if [ $? -ne 0 ]; then
        RESTORE_SUCCESS=false
    fi
fi

if [ "$LOG_EXISTS" = true ]; then
    wait $LOG_PID
    if [ $? -ne 0 ]; then
        RESTORE_SUCCESS=false
    fi
fi

if [ "$SNAPSHOT_EXISTS" = true ]; then
    wait $SNAPSHOT_PID
    if [ $? -ne 0 ]; then
        RESTORE_SUCCESS=false
    fi
fi

# Show final status
if [ "$RESTORE_SUCCESS" = true ]; then
    echo -e "\n${GREEN}All restore processes completed successfully!${NC}"
    exit 0
else
    echo -e "\n${RED}Some restore processes failed. Please check the output above.${NC}"
    exit 1
fi
