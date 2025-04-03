#!/bin/bash
#
# Author: skipper
# Created: 2025-04-03
#

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to validate version format (major.minor.patch)
validate_version() {
    if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Version must be in major.minor.patch format (e.g., 10.2.7)${NC}"
        exit 1
    fi
}

# Function to check if mysqldump exists
check_mysqldump() {
    if ! command -v mysqldump &> /dev/null; then
        echo -e "${RED}Error: mysqldump is not installed.${NC}"
        echo "Please install MySQL client tools and try again."
        echo "You can install it using one of these commands:"
        echo "  - For Ubuntu/Debian: sudo apt-get install mysql-client"
        echo "  - For CentOS/RHEL: sudo yum install mysql"
        echo "  - For macOS: brew install mysql-client"
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

# Check if mysqldump is available
check_mysqldump

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

# Check if any backup files already exist
if [ -f "querypie.sql" ] || [ -f "querypie_log.sql" ] || [ -f "querypie_snapshot.sql" ]; then
    echo -e "${RED}Error: Backup files already exist in $TARGET_DIR${NC}"
    echo "Existing backup files:"
    ls -lh querypie*.sql 2>/dev/null
    echo -e "\nPlease remove or rename existing backup files before running the backup script."
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

# Initialize completion flags
QUERYPIE_COMPLETED=false
LOG_COMPLETED=false
SNAPSHOT_COMPLETED=false

# Function to display backup files
display_backup_files() {
    echo -e "\n${GREEN}=== Backup files in $TARGET_DIR ===${NC}"
    echo -e "Last updated: $(date '+%Y-%m-%d %H:%M:%S')\n"
    
    # Check querypie backup
    if [ "$QUERYPIE_COMPLETED" = false ] && ! ps -p $QUERYPIE_PID > /dev/null; then
        QUERYPIE_COMPLETED=true
        if [ -f "./querypie.sql" ]; then
            echo -e "${GREEN}✓ querypie backup just completed!${NC}"
        fi
    fi
    
    # Check log backup
    if [ "$LOG_COMPLETED" = false ] && ! ps -p $LOG_PID > /dev/null; then
        LOG_COMPLETED=true
        if [ -f "./querypie_log.sql" ]; then
            echo -e "${GREEN}✓ querypie_log backup just completed!${NC}"
        fi
    fi
    
    # Check snapshot backup
    if [ "$SNAPSHOT_COMPLETED" = false ] && ! ps -p $SNAPSHOT_PID > /dev/null; then
        SNAPSHOT_COMPLETED=true
        if [ -f "./querypie_snapshot.sql" ]; then
            echo -e "${GREEN}✓ querypie_snapshot backup just completed!${NC}"
        fi
    fi
    
    # Display current status of all files
    for file in "querypie.sql" "querypie_log.sql" "querypie_snapshot.sql"; do
        if [ -f "$file" ]; then
            ls -lh "$file"
        else
            echo "$file - Not created yet"
        fi
    done
    
    echo -e "${GREEN}----------------------------------------${NC}"
    echo -e "Will refresh in 10 seconds..."
    echo -e "Press Ctrl+C to stop monitoring"
}

# Execute database backups
echo -e "${GREEN}Starting database backups...${NC}"

# Start backup processes
QUERYPIE_CMD="mysqldump -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'${DB_PASSWORD}' --databases ${DB_CATALOG:-querypie} > ./querypie.sql"
DISPLAY_CMD="mysqldump -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'hidden' --databases ${DB_CATALOG:-querypie} > ./querypie.sql"
echo "Executing: ${DISPLAY_CMD}"
nohup bash -c "$QUERYPIE_CMD" >/dev/null 2>&1 &
QUERYPIE_PID=$!

LOG_CMD="mysqldump -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'${DB_PASSWORD}' --databases ${LOG_DB_CATALOG:-querypie_log} > ./querypie_log.sql"
DISPLAY_CMD="mysqldump -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'hidden' --databases ${LOG_DB_CATALOG:-querypie_log} > ./querypie_log.sql"
echo "Executing: ${DISPLAY_CMD}"
nohup bash -c "$LOG_CMD" >/dev/null 2>&1 &
LOG_PID=$!

SNAPSHOT_CMD="mysqldump -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'${DB_PASSWORD}' --databases ${ENG_DB_CATALOG:-querypie_snapshot} > ./querypie_snapshot.sql"
DISPLAY_CMD="mysqldump -h${DB_HOST} -P${DB_PORT} -u${DB_USERNAME} -p'hidden' --databases ${ENG_DB_CATALOG:-querypie_snapshot} > ./querypie_snapshot.sql"
echo "Executing: ${DISPLAY_CMD}"
nohup bash -c "$SNAPSHOT_CMD" >/dev/null 2>&1 &
SNAPSHOT_PID=$!

echo -e "\n${GREEN}All backup processes have been started in the background${NC}"

# Monitor backup progress
ALL_COMPLETED=false
LAST_DISPLAY_TIME=0

while [ "$ALL_COMPLETED" = false ]; do
    CURRENT_TIME=$(date +%s)
    
    # Display status every 10 seconds
    if [ $((CURRENT_TIME - LAST_DISPLAY_TIME)) -ge 10 ] || [ "$LAST_DISPLAY_TIME" = 0 ]; then
        display_backup_files
        LAST_DISPLAY_TIME=$CURRENT_TIME
    fi
    
    # Check if all processes are complete (every 1 second)
    if ! ps -p $QUERYPIE_PID > /dev/null && \
       ! ps -p $LOG_PID > /dev/null && \
       ! ps -p $SNAPSHOT_PID > /dev/null; then
        ALL_COMPLETED=true
    else
        sleep 1
    fi
done

# Final status check
echo -e "\n${GREEN}All backup processes completed!${NC}"
echo -e "Final backup status:\n"

BACKUP_SUCCESS=true

if [ -f "./querypie.sql" ]; then
    echo -e "${GREEN}✓ querypie backup completed${NC}"
    ls -lh "./querypie.sql"
else
    echo -e "${RED}✗ querypie backup failed${NC}"
    BACKUP_SUCCESS=false
fi

if [ -f "./querypie_log.sql" ]; then
    echo -e "${GREEN}✓ querypie_log backup completed${NC}"
    ls -lh "./querypie_log.sql"
else
    echo -e "${RED}✗ querypie_log backup failed${NC}"
    BACKUP_SUCCESS=false
fi

if [ -f "./querypie_snapshot.sql" ]; then
    echo -e "${GREEN}✓ querypie_snapshot backup completed${NC}"
    ls -lh "./querypie_snapshot.sql"
else
    echo -e "${RED}✗ querypie_snapshot backup failed${NC}"
    BACKUP_SUCCESS=false
fi

if [ "$BACKUP_SUCCESS" = true ]; then
    echo -e "\n${GREEN}All backups completed successfully!${NC}"
    exit 0
else
    echo -e "\n${RED}Some backups failed. Please check the output above.${NC}"
    exit 1
fi
