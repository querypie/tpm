#!/bin/bash
#
# QueryPie Scanner - MySQL and Redis Connection Test Tool
# 
# Usage:
#   ./scanner.sh              - Basic execution
#   ./scanner.sh -v           - Verbose mode
#   ./scanner.sh <container>  - Specify container ID or name
#

# =============================================================================
# Global Variables and Constants
# =============================================================================

# Script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# compose-env file path
COMPOSE_ENV_FILE="${SCRIPT_DIR}/compose-env"

# Default Docker container name
CONTAINER_NAME="mysql-client-container"

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[1;96m'
NC='\033[0m' # No Color

# Status variables initialization
VERBOSE=false
CONTAINER_ID=""
CONTAINER_PARAM=""
MYSQL_PORT_OPEN=false
REDIS_PORT_OPEN=false
TIMEOUT_CMD="timeout 5"
MYSQL_CLIENT_AVAILABLE=false

# DB and Redis connection variables
DB_HOST=""
DB_PORT=""
DB_USER=""
DB_PASSWORD=""
DB_NAME=""
REDIS_HOST=""
REDIS_PORT=""
REDIS_PASSWORD=""

# Test results
LOCAL_MYSQL_RESULT=1
LOCAL_REDIS_RESULT=1
MYSQL_RESULT=1
REDIS_RESULT=1

# =============================================================================
# Utility Functions
# =============================================================================

# Log output functions
function log_info() {
    if [[ "$1" == *"====== QUERYPIE SCANNING"* ]]; then
        echo -e "${BLUE}$1${NC}"
    elif [[ "$1" == *"Testing MySQL Connection"* ]] || [[ "$1" == *"Testing Redis Connection"* ]]; then
        echo -e "${BLUE}🔄 $1${NC}"
    elif $VERBOSE; then
        echo -e "${BLUE}$1${NC}"
    fi
}

function log_success() {
    echo -e "${GREEN}$1${NC}"
}

function log_warning() {
    echo -e "${YELLOW}$1${NC}"
}

function log_error() {
    echo -e "${RED}$1${NC}"
}

function log_debug() {
    if $VERBOSE; then
        echo -e "${YELLOW}$1${NC}"
    fi
}

# Help display function
function show_help() {
    echo "QueryPie Scanner - MySQL and Redis Connection Test Tool"
    echo ""
    echo "Usage:"
    echo "  ./scanner.sh              - Basic execution"
    echo "  ./scanner.sh -v           - Verbose mode"
    echo "  ./scanner.sh <container>  - Specify container ID or name"
    echo "  ./scanner.sh -h           - Show help"
    echo ""
    exit 0
}

# Convert Docker host names to localhost
function convert_docker_host() {
    local host="$1"
    case "${host}" in
        "host.docker.internal"|"docker.for.mac.localhost"|"docker.for.win.localhost"|"docker.localhost"|"localhost")
            echo "127.0.0.1"
            ;;
        *)
            echo "${host}"
            ;;
    esac
}

# Check if a port is open
function is_port_open() {
    local host=$1
    local port=$2
    
    # Run the test within Docker container
    docker exec ${CONTAINER_ID} bash -c "timeout 3 bash -c 'echo > /dev/tcp/${host}/${port}'" 2>/dev/null
    return $?
}

# =============================================================================
# Environment Setup Functions
# =============================================================================

# Command line argument processing
function parse_arguments() {
    # Check help option
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
    fi

    # Check verbose mode
    if [ "$1" = "-v" ] || [ "$2" = "-v" ]; then
        VERBOSE=true
        log_debug "Verbose mode activated"
    fi

    # If container ID or name is provided as parameter
    if [ "$1" != "" ] && [ "$1" != "-v" ]; then
        CONTAINER_PARAM="$1"
        log_debug "Container specified: ${CONTAINER_PARAM}"
    fi
}

# Load environment variables
function load_environment_variables() {
    log_debug "Loading environment variables..."
    
    # Check if compose-env file exists
    if [ ! -f "${COMPOSE_ENV_FILE}" ]; then
        log_error "Error: compose-env file not found: ${COMPOSE_ENV_FILE}"
        exit 1
    fi

    # Extract DB connection info from compose-env file
    DB_HOST=$(grep "^DB_HOST=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    DB_PORT=$(grep "^DB_PORT=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    DB_USER=$(grep "^DB_USERNAME=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    DB_PASSWORD=$(grep "^DB_PASSWORD=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    DB_NAME=$(grep "^DB_CATALOG=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    REDIS_HOST=$(grep "^REDIS_HOST=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    REDIS_PORT=$(grep "^REDIS_PORT=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    
    log_debug "Environment variables loaded"
}

# =============================================================================
# Docker Container Functions
# =============================================================================

# Docker container setup
function setup_docker_container() {
    if [ "$VERBOSE" = true ]; then
        echo -e "\n${BLUE}====== SETTING UP DOCKER CONTAINER ======${NC}\n"
    fi
    
    # If container ID is provided as parameter
    if [ -n "$CONTAINER_PARAM" ]; then
        if [ "$VERBOSE" = true ]; then
            echo -e "Container specified: ${CONTAINER_PARAM}"
            echo -e "\nAvailable containers:"
            docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}" | cat
            echo -e ""
        fi
        
        # Try to find container by exact name
        CONTAINER_ID=$(docker ps -q -f name="^${CONTAINER_PARAM}$")
        
        if [ -z "$CONTAINER_ID" ]; then
            log_error "Error: Container '${CONTAINER_PARAM}' not found or not running"
            exit 1
        fi
    # If no container ID is provided, search for a querypie container
    elif [ -z "$CONTAINER_ID" ]; then
        if [ "$VERBOSE" = true ]; then
            echo -e "No container specified, searching for querypie containers..."
            echo -e "\nAvailable containers:"
            docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}" | cat
            echo -e ""
        fi
        
        # Find running containers that match querypie but aren't MySQL or Redis
        CONTAINER_ID=$(docker ps --format '{{.ID}} {{.Names}}' | grep -i "querypie" | grep -v -i "mysql\|redis" | head -1 | awk '{print $1}')
        
        # If no querypie container found, use default container
        if [ -z "$CONTAINER_ID" ]; then
            if [ "$VERBOSE" = true ]; then
                echo -e "No querypie containers found. Using default container: mysql-client-container"
            fi
            
            # Check if our default container exists
            if ! docker ps -q -f name=mysql-client-container 2>/dev/null | grep -q .; then
                # Container doesn't exist, create it
                docker run -d --name mysql-client-container -v "$(pwd):/app" --workdir /app mysql:latest tail -f /dev/null >/dev/null 2>&1
                
                # Wait for container to be ready
                sleep 2
            fi
            
            CONTAINER_ID=$(docker ps -q -f name=mysql-client-container)
        fi
    fi

    # Show selected container details
    if [ "$VERBOSE" = true ]; then
        echo -e "\nSelected container details:"
        docker ps -f id=$CONTAINER_ID --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" | cat
        echo -e ""
    fi
    
    # Check if MySQL client is available in the container
    if docker exec $CONTAINER_ID which mysql >/dev/null 2>&1; then
        MYSQL_CLIENT_AVAILABLE=true
        if [ "$VERBOSE" = true ]; then
            echo -e "MySQL client is available in the container"
        fi
    else
        MYSQL_CLIENT_AVAILABLE=false
        if [ "$VERBOSE" = true ]; then
            echo -e "Warning: MySQL client not found in container ${CONTAINER_ID}"
        fi
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo -e "Docker container setup complete: ${CONTAINER_ID}"
    fi
}

# Check container resources
function check_container_resources() {
    if $VERBOSE; then
        log_info "\n====== CHECKING CONTAINER RESOURCES ======"

        # Get container stats using docker stats (one-time snapshot)
        local STATS=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" ${CONTAINER_ID})
        
        # Parse stats
        local CPU_USAGE=$(echo "$STATS" | cut -f1)
        local MEM_USAGE=$(echo "$STATS" | cut -f2)
        local MEM_PERC=$(echo "$STATS" | cut -f3)
        local NET_IO=$(echo "$STATS" | cut -f4)
        local BLOCK_IO=$(echo "$STATS" | cut -f5)

        # Get disk usage inside container
        local DISK_USAGE=$(docker exec ${CONTAINER_ID} df -h / | tail -n 1)
        local DISK_TOTAL=$(echo "$DISK_USAGE" | awk '{print $2}')
        local DISK_USED=$(echo "$DISK_USAGE" | awk '{print $3}')
        local DISK_AVAIL=$(echo "$DISK_USAGE" | awk '{print $4}')
        local DISK_PERC=$(echo "$DISK_USAGE" | awk '{print $5}')

        # Display resource information
        echo -e "\nContainer Resource Usage:"
        echo "CPU Usage: ${CPU_USAGE}"
        echo "Memory Usage: ${MEM_USAGE} (${MEM_PERC})"
        echo "Network I/O: ${NET_IO}"
        echo "Block I/O: ${BLOCK_IO}"
        echo -e "\nContainer Disk Usage:"
        echo "Total: ${DISK_TOTAL}"
        echo "Used: ${DISK_USED} (${DISK_PERC})"
        echo "Available: ${DISK_AVAIL}"

        # Get detailed CPU info
        log_debug "\nDetailed CPU Information:"
        echo "CPU Cores: $(docker exec ${CONTAINER_ID} nproc)"
        
        # Get CPU model using cat /proc/cpuinfo (if available)
        local CPU_MODEL=$(docker exec ${CONTAINER_ID} cat /proc/cpuinfo 2>/dev/null | grep "model name" | head -1 | cut -d':' -f2- || echo "Not available")
        echo "CPU Model:${CPU_MODEL}"

        # Get memory info from /proc/meminfo
        log_debug "\nDetailed Memory Information:"
        docker exec ${CONTAINER_ID} cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree"

        # Get detailed disk info
        log_debug "\nDetailed Disk Information:"
        docker exec ${CONTAINER_ID} df -h
        echo -e ""
    fi
}

# =============================================================================
# MySQL Test Functions
# =============================================================================

# Test MySQL connection from local environment
function test_mysql_local() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}====== TESTING MYSQL CONNECTION FROM LOCAL ENVIRONMENT ======${NC}"
        echo -e "Using MySQL connection info:"
        echo -e "DB_HOST: 127.0.0.1 (original: $DB_HOST)"
        echo -e "DB_PORT: $DB_PORT"
        echo -e "DB_USERNAME: $DB_USERNAME"
        echo -e "DB_CATALOG: $DB_CATALOG"
        echo -e "DB_PASSWORD: ******** (hidden)"
    fi

    # Check if the MySQL port is open
    if nc -z -w 3 127.0.0.1 $DB_PORT 2>/dev/null; then
        echo -e "${GREEN}✓ MySQL port $DB_PORT is OPEN${NC}"
        
        local mysql_client_available=false
        # Check if mysql client is available locally
        if command -v mysql &>/dev/null; then
            mysql_client_available=true
            if [ "$VERBOSE" = true ]; then
                echo -e "Using MySQL client for testing..."
            fi
            
            # Test with local mysql client
            MYSQL_VERSION=$(mysql \
                -h "127.0.0.1" \
                -P "${DB_PORT}" \
                -u "${DB_USERNAME}" \
                -p"${DB_PASSWORD}" \
                ${DB_CATALOG:+-D "${DB_CATALOG}"} \
                --protocol=TCP \
                --default-auth=mysql_native_password \
                --ssl \
                -e "SELECT VERSION() as 'MySQL Server Version';" 2>/dev/null | grep -v "MySQL Server Version" | tr -d "\r\n ")
            
            if mysql \
                -h "127.0.0.1" \
                -P "${DB_PORT}" \
                -u "${DB_USERNAME}" \
                -p"${DB_PASSWORD}" \
                ${DB_CATALOG:+-D "${DB_CATALOG}"} \
                --protocol=TCP \
                --default-auth=mysql_native_password \
                --ssl \
                -e "SELECT 'MySQL connection successful!' as Status;" &>/dev/null; then
                
                echo -e "${GREEN}✅ MySQL connection test: SUCCESS (using mysql client)${NC}"
                if [ "$VERBOSE" = true ]; then
                    echo -e "   Server version: $MYSQL_VERSION"
                fi
                LOCAL_MYSQL_RESULT=0
                echo -e ""
                return 0
            fi
        fi
        
        # Try netcat as a fallback or if mysql client failed
        if [ "$mysql_client_available" = false ] || [ $LOCAL_MYSQL_RESULT -ne 0 ]; then
            if [ "$VERBOSE" = true ]; then
                echo -e "Testing MySQL connection using netcat..."
            fi
            
            # Try to connect and capture the server greeting
            MYSQL_GREETING=$(bash -c "{ 
                sleep 1
                printf '\x4a\x00\x00\x00\x0a'
                printf '8.4.4\x00'
                printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
                printf '\x00'
                printf '\x00'
                printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
                printf '\x00'
                printf '\x00\x00'
                printf '\x00\x00\x00\x00'
                printf '\x00'
                printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
                printf '\x00'
                printf '\x00'
            } | nc -w 3 127.0.0.1 ${DB_PORT} | tr -d '\0'" 2>/dev/null)
            
            # Check if we got a MySQL server greeting
            if echo "$MYSQL_GREETING" | grep -q "mysql\|8\."; then
                echo -e "${GREEN}✅ MySQL connection test: SUCCESS (using netcat)${NC}"
                
                # Try to extract version from greeting
                MYSQL_VERSION=$(echo "$MYSQL_GREETING" | grep -o -E "([0-9]+\.)+[0-9]+" | head -1)
                if [ "$VERBOSE" = true ]; then
                    echo -e "   Server version: $MYSQL_VERSION (estimated from greeting)"
                    echo -e "Command: nc -w 3 127.0.0.1 $DB_PORT"
                    echo -e "Server greeting detected: MySQL server is responding"
                    echo -e "Raw server response: $MYSQL_GREETING"
                fi
                LOCAL_MYSQL_RESULT=0
                echo -e ""
                return 0
            else
                if [ "$VERBOSE" = true ]; then
                    echo -e "Netcat test failed, trying SSH..."
                fi
                
                # Try SSH as a last resort
                if command -v ssh &>/dev/null; then
                    if run_mysql_test_with_ssh "127.0.0.1"; then
                        echo -e "${GREEN}✅ MySQL connection test: SUCCESS (using SSH)${NC}"
                        if [ "$VERBOSE" = true ]; then
                            echo -e "   Server version: $MYSQL_VERSION (estimated from greeting)"
                            echo -e "Command: ssh root@127.0.0.1 'nc -w 3 127.0.0.1 $DB_PORT'"
                            echo -e "Server greeting detected: MySQL server is responding"
                        fi
                        LOCAL_MYSQL_RESULT=0
                        echo -e ""
                        return 0
                    fi
                fi
                
                echo -e "${RED}❌ MySQL connection test: FAILED${NC}"
                if [ "$VERBOSE" = true ]; then
                    echo -e "Command: nc -w 3 127.0.0.1 $DB_PORT"
                    echo -e "No valid MySQL server greeting detected"
                    
                    echo -e "\nMySQL Troubleshooting:"
                    echo "1. Check if the MySQL server is running on 127.0.0.1:${DB_PORT}"
                    echo "2. Verify that the user has proper permissions"
                    echo "3. Try removing SSL options if you're getting SSL-related errors"
                fi
                echo -e ""
            fi
        fi
    else
        echo -e "${RED}✗ MySQL port $DB_PORT is CLOSED or unreachable${NC}"
        if [ "$VERBOSE" = true ]; then
            echo -e "\nMySQL Troubleshooting:"
            echo "1. Check if the MySQL server is running on 127.0.0.1:${DB_PORT}"
            echo "2. Make sure the MySQL server is binding to the correct interface"
        fi
        echo -e ""
    fi
    
    return 1
}

# Test MySQL connection from Docker container
function test_mysql_connection() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}====== TESTING MYSQL CONNECTION FROM DOCKER CONTAINER ======${NC}"
        echo -e "Using MySQL connection info:"
        echo -e "DB_HOST: $DB_HOST"
        echo -e "DB_PORT: $DB_PORT"
        echo -e "DB_USERNAME: $DB_USERNAME"
        echo -e "DB_CATALOG: $DB_CATALOG"
        echo -e "DB_PASSWORD: ******** (hidden)"
    fi

    # Check if the port is open
    if is_port_open "$DB_HOST" "$DB_PORT"; then
        echo -e "${GREEN}✓ MySQL port $DB_PORT is OPEN${NC}"
        
        # Test with mysql client
        if run_mysql_test_with_client "$DB_HOST"; then
            echo -e "${GREEN}✅ MySQL connection test: SUCCESS (using mysql client)${NC}"
            if [ "$VERBOSE" = true ]; then
                echo -e "   Server version: $MYSQL_VERSION"
            fi
            MYSQL_RESULT=0
            echo -e ""
        else
            # If mysql client fails, try netcat
            if [ "$VERBOSE" = true ]; then
                echo -e "MySQL client failed, trying netcat..."
            fi
            
            if run_mysql_test_with_netcat "$DB_HOST"; then
                echo -e "${GREEN}✅ MySQL connection test: SUCCESS (using netcat)${NC}"
                if [ "$VERBOSE" = true ]; then
                    echo -e "   Server version: $MYSQL_VERSION (estimated from greeting)"
                    echo -e "Command: nc -w 3 $DB_HOST $DB_PORT"
                    echo -e "Server greeting detected: MySQL server is responding"
                fi
                MYSQL_RESULT=0
                echo -e ""
            else
                # If netcat fails, try SSH
                if [ "$VERBOSE" = true ]; then
                    echo -e "Netcat test failed, trying SSH..."
                fi
                
                if docker exec ${CONTAINER_ID} which ssh >/dev/null 2>&1; then
                    if run_mysql_test_with_ssh "$DB_HOST"; then
                        echo -e "${GREEN}✅ MySQL connection test: SUCCESS (using SSH)${NC}"
                        if [ "$VERBOSE" = true ]; then
                            echo -e "   Server version: $MYSQL_VERSION (estimated from greeting)"
                            echo -e "Command: ssh root@$DB_HOST 'nc -w 3 127.0.0.1 $DB_PORT'"
                            echo -e "Server greeting detected: MySQL server is responding"
                        fi
                        MYSQL_RESULT=0
                        echo -e ""
                    else
                        echo -e "${RED}❌ MySQL connection test: FAILED${NC}"
                        if [ "$VERBOSE" = true ]; then
                            show_mysql_troubleshooting "$DB_HOST"
                        fi
                        echo -e ""
                    fi
                else
                    echo -e "${RED}❌ MySQL connection test: FAILED (SSH not available in container)${NC}"
                    if [ "$VERBOSE" = true ]; then
                        show_mysql_troubleshooting "$DB_HOST"
                    fi
                    echo -e ""
                fi
            fi
        fi
    else
        echo -e "${RED}✗ MySQL port $DB_PORT is CLOSED or unreachable${NC}"
        if [ "$VERBOSE" = true ]; then
            show_mysql_troubleshooting "$DB_HOST"
        fi
        echo -e ""
    fi
}

# Test MySQL using the client
function run_mysql_test_with_client() {
    local host=$1
    
    # Get MySQL version
    MYSQL_VERSION=$(docker exec ${CONTAINER_ID} mysql \
        -h "${host}" \
        -P "${DB_PORT}" \
        -u "${DB_USERNAME}" \
        -p"${DB_PASSWORD}" \
        ${DB_CATALOG:+-D "${DB_CATALOG}"} \
        --protocol=TCP \
        --default-auth=mysql_native_password \
        --ssl \
        -e "SELECT VERSION() as 'MySQL Server Version';" 2>/dev/null | grep -v "MySQL Server Version" | tr -d "\r\n ")
    
    # Test connection
    if docker exec ${CONTAINER_ID} mysql \
        -h "${host}" \
        -P "${DB_PORT}" \
        -u "${DB_USERNAME}" \
        -p"${DB_PASSWORD}" \
        ${DB_CATALOG:+-D "${DB_CATALOG}"} \
        --protocol=TCP \
        --default-auth=mysql_native_password \
        --ssl \
        -e "SELECT 'MySQL connection successful!' as Status;" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Test MySQL using netcat
function run_mysql_test_with_netcat() {
    local host=$1
    
    # Try to connect and capture the server greeting
    MYSQL_GREETING=$(docker exec ${CONTAINER_ID} bash -c "{ 
        sleep 1
        printf '\x4a\x00\x00\x00\x0a'
        printf '8.4.4\x00'
        printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        printf '\x00'
        printf '\x00'
        printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        printf '\x00'
        printf '\x00\x00'
        printf '\x00\x00\x00\x00'
        printf '\x00'
        printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        printf '\x00'
        printf '\x00'
    } | nc -w 3 ${host} ${DB_PORT} | tr -d '\0'" 2>/dev/null)
    
    # Check if we got a MySQL server greeting
    if echo "$MYSQL_GREETING" | grep -q "mysql\|8\."; then
        # Try to extract version from greeting
        MYSQL_VERSION=$(echo "$MYSQL_GREETING" | grep -o -E "([0-9]+\.)+[0-9]+" | head -1)
        return 0
    else
        return 1
    fi
}

# Test MySQL using SSH
function run_mysql_test_with_ssh() {
    local host=$1
    
    # Try to connect and capture the server greeting using SSH
    MYSQL_GREETING=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -p 22 root@${host} "bash -c '{ 
        sleep 1
        printf '\x4a\x00\x00\x00\x0a'
        printf '8.4.4\x00'
        printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        printf '\x00'
        printf '\x00'
        printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        printf '\x00'
        printf '\x00\x00'
        printf '\x00\x00\x00\x00'
        printf '\x00'
        printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        printf '\x00'
        printf '\x00'
    } | nc -w 3 127.0.0.1 ${DB_PORT} | tr -d '\0'" 2>/dev/null)
    
    # Check if we got a MySQL server greeting
    if echo "$MYSQL_GREETING" | grep -q "mysql\|8\."; then
        # Try to extract version from greeting
        MYSQL_VERSION=$(echo "$MYSQL_GREETING" | grep -o -E "([0-9]+\.)+[0-9]+" | head -1)
        return 0
    else
        return 1
    fi
}

# Show MySQL troubleshooting info
function show_mysql_troubleshooting() {
    local host=$1
    
    echo -e "\nMySQL Troubleshooting:"
    echo "1. Check if the MySQL server is running on ${host}:${DB_PORT}"
    echo "2. Verify that the user has proper permissions"
    echo "3. If using 'host.docker.internal', make sure your Docker version supports it"
    echo "4. Try removing SSL options if you're getting SSL-related errors"
}

# =============================================================================
# Redis Test Functions
# =============================================================================

# Test Redis connection from local environment
function test_redis_local() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}====== TESTING REDIS CONNECTION FROM LOCAL ENVIRONMENT ======${NC}"
        echo -e "Using Redis connection info:"
        echo -e "REDIS_HOST: 127.0.0.1 (original: $REDIS_HOST)"
        echo -e "REDIS_PORT: $REDIS_PORT"
        echo -e "REDIS_PASSWORD: ******** (hidden)"
    fi

    # Check if the Redis port is open
    if nc -z -w 3 127.0.0.1 $REDIS_PORT 2>/dev/null; then
        echo -e "${GREEN}✓ Redis port $REDIS_PORT is OPEN${NC}"
        
        local redis_cli_available=false
        # Try redis-cli first if available
        if command -v redis-cli &>/dev/null; then
            redis_cli_available=true
            if [ "$VERBOSE" = true ]; then
                echo -e "Using redis-cli for testing..."
            fi
            
            # Test Redis connection with redis-cli
            if [ -z "${REDIS_PASSWORD}" ]; then
                # No password
                REDIS_TEST_OUTPUT=$(redis-cli -h "127.0.0.1" -p "${REDIS_PORT}" PING 2>/dev/null)
                REDIS_SERVER_INFO=$(redis-cli -h "127.0.0.1" -p "${REDIS_PORT}" INFO SERVER 2>/dev/null)
            else
                # With password
                REDIS_TEST_OUTPUT=$(redis-cli -h "127.0.0.1" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" PING 2>/dev/null)
                REDIS_SERVER_INFO=$(redis-cli -h "127.0.0.1" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" INFO SERVER 2>/dev/null)
            fi
            
            if [ "$REDIS_TEST_OUTPUT" = "PONG" ]; then
                echo -e "${GREEN}✅ Redis connection test: SUCCESS (using redis-cli)${NC}"
                
                # Try to extract version from server info
                if echo "$REDIS_SERVER_INFO" | grep -q "redis_version"; then
                    REDIS_VERSION=$(echo "$REDIS_SERVER_INFO" | grep "redis_version" | cut -d ":" -f2 | tr -d "\r\n ")
                    if [ "$VERBOSE" = true ]; then
                        echo -e "   Server version: $REDIS_VERSION"
                    fi
                fi
                
                LOCAL_REDIS_RESULT=0
                echo -e ""
                return 0
            else
                if [ "$VERBOSE" = true ]; then
                    echo -e "${RED}❌ Redis connection test: FAILED (using redis-cli)${NC}"
                    echo -e "Falling back to netcat..."
                fi
            fi
        else
            if [ "$VERBOSE" = true ]; then
                echo -e "Redis CLI not found in local environment, trying netcat..."
            fi
        fi
        
        # If redis-cli failed or isn't available, try netcat
        if [ "$redis_cli_available" = false ] || [ $LOCAL_REDIS_RESULT -ne 0 ]; then
            if [ "$VERBOSE" = true ]; then
                echo -e "Testing Redis connection using netcat..."
            fi
            
            # Handle cases with and without password
            local redis_test_output=""
            if [ -z "${REDIS_PASSWORD}" ]; then
                # No password - simple PING test
                redis_test_output=$(bash -c "echo -e 'PING\r\n' | nc -w 3 127.0.0.1 ${REDIS_PORT}" 2>/dev/null)
                
                # Try to get version info if successful
                if echo "$redis_test_output" | grep -q "+PONG"; then
                    REDIS_SERVER_INFO=$(bash -c "echo -e 'INFO SERVER\r\n' | nc -w 3 127.0.0.1 ${REDIS_PORT}" 2>/dev/null)
                fi
            else
                # With password - AUTH command followed by PING
                redis_test_output=$(bash -c "{ echo -e \"AUTH ${REDIS_PASSWORD}\r\nPING\r\nQUIT\r\n\"; } | nc -w 3 127.0.0.1 ${REDIS_PORT}" 2>/dev/null)
                
                # Try to get version info if successful
                if echo "$redis_test_output" | grep -q "+PONG"; then
                    REDIS_SERVER_INFO=$(bash -c "{ echo -e \"AUTH ${REDIS_PASSWORD}\r\nINFO SERVER\r\nQUIT\r\n\"; } | nc -w 3 127.0.0.1 ${REDIS_PORT}" 2>/dev/null)
                fi
            fi
            
            # Check for successful PING response
            if echo "$redis_test_output" | grep -q "+PONG"; then
                echo -e "${GREEN}✅ Redis connection test: SUCCESS (using netcat with AUTH)${NC}"
                
                # Try to extract version from server info
                if echo "$REDIS_SERVER_INFO" | grep -q "redis_version"; then
                    REDIS_VERSION=$(echo "$REDIS_SERVER_INFO" | grep "redis_version" | cut -d ":" -f2 | tr -d "\r\n ")
                    if [ "$VERBOSE" = true ]; then
                        echo -e "   Server version: $REDIS_VERSION"
                        echo -e "Command: AUTH ... | PING | nc -w 3 127.0.0.1 $REDIS_PORT"
                        echo -e "Result: $redis_test_output"
                    fi
                fi
                
                LOCAL_REDIS_RESULT=0
                echo -e ""
                return 0
            else
                if [ "$VERBOSE" = true ]; then
                    echo -e "Netcat test failed, trying SSH..."
                fi
                
                # Try SSH as a last resort
                if command -v ssh &>/dev/null; then
                    if run_redis_test_with_ssh "127.0.0.1"; then
                        echo -e "${GREEN}✅ Redis connection test: SUCCESS (using SSH)${NC}"
                        
                        # Try to extract version from server info
                        if echo "$REDIS_SERVER_INFO" | grep -q "redis_version"; then
                            REDIS_VERSION=$(echo "$REDIS_SERVER_INFO" | grep "redis_version" | cut -d ":" -f2 | tr -d "\r\n ")
                            if [ "$VERBOSE" = true ]; then
                                echo -e "   Server version: $REDIS_VERSION"
                                echo -e "Command: ssh root@127.0.0.1 'nc -w 3 127.0.0.1 $REDIS_PORT'"
                                echo -e "Result: $redis_test_output"
                            fi
                        fi
                        
                        LOCAL_REDIS_RESULT=0
                        echo -e ""
                        return 0
                    fi
                fi
                
                echo -e "${RED}❌ Redis connection test: FAILED${NC}"
                if [ "$VERBOSE" = true ]; then
                    echo -e "Command: AUTH ... | PING | nc -w 3 127.0.0.1 $REDIS_PORT"
                    echo -e "Result: $redis_test_output"
                    
                    echo -e "\nRedis Troubleshooting:"
                    echo "1. Check if the Redis server is running on 127.0.0.1:${REDIS_PORT}"
                    echo "2. If using a password, verify it is correct"
                    echo "3. Make sure Redis allows external connections (bind to 0.0.0.0)"
                    echo "4. Check if protected-mode is set to 'no' in redis.conf"
                fi
                echo -e ""
            fi
        fi
    else
        echo -e "${RED}✗ Redis port $REDIS_PORT is CLOSED or unreachable${NC}"
        if [ "$VERBOSE" = true ]; then
            echo -e "\nRedis Troubleshooting:"
            echo "1. Check if the Redis server is running on 127.0.0.1:${REDIS_PORT}"
            echo "2. Make sure the Redis server is binding to the correct interface"
        fi
        echo -e ""
    fi
    
    return 1
}

# Test Redis connection from Docker container
function test_redis_connection() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}====== TESTING REDIS CONNECTION FROM DOCKER CONTAINER ======${NC}"
        echo -e "Using Redis connection info:"
        echo -e "REDIS_HOST: $REDIS_HOST"
        echo -e "REDIS_PORT: $REDIS_PORT"
        echo -e "REDIS_PASSWORD: ******** (hidden)"
    fi

    # Check if the Redis port is open
    if is_port_open "$REDIS_HOST" "$REDIS_PORT"; then
        echo -e "${GREEN}✓ Redis port $REDIS_PORT is OPEN${NC}"
        
        # Try redis-cli first
        if [ "$VERBOSE" = true ]; then
            echo -e "Testing Redis connection using redis-cli..."
        fi
        
        local redis_output
        redis_output=$(docker exec ${CONTAINER_ID} redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ${REDIS_PASSWORD:+-a "${REDIS_PASSWORD}"} PING 2>&1)
        
        if echo "$redis_output" | grep -q "PONG"; then
            echo -e "${GREEN}✅ Redis connection test: SUCCESS (using redis-cli)${NC}"
            if [ "$VERBOSE" = true ]; then
                echo -e "   Host: $REDIS_HOST:$REDIS_PORT, Auth: ${REDIS_PASSWORD:+Yes}"
                if echo "$redis_output" | grep -q "AUTH failed"; then
                    echo -e "${RED}   Note: AUTH warning received but connection successful${NC}"
                fi
                # Get server version
                REDIS_SERVER_INFO=$(docker exec ${CONTAINER_ID} redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ${REDIS_PASSWORD:+-a "${REDIS_PASSWORD}"} INFO SERVER 2>&1)
                if echo "$REDIS_SERVER_INFO" | grep -q "redis_version"; then
                    REDIS_VERSION=$(echo "$REDIS_SERVER_INFO" | grep "redis_version" | cut -d ":" -f2 | tr -d "\r\n ")
                    echo -e "   Server version: $REDIS_VERSION"
                fi
            fi
            REDIS_RESULT=0
            echo -e ""
        else
            # If redis-cli fails, try netcat
            if [ "$VERBOSE" = true ]; then
                echo -e "Redis CLI failed, trying netcat..."
                echo -e "Testing Redis connection using netcat..."
            fi
            
            local auth_result
            auth_result=$(run_redis_test_with_netcat "$REDIS_HOST")
            local success=$?
            
            if [ $success -eq 0 ]; then
                echo -e "${GREEN}✅ Redis connection test: SUCCESS (using netcat)${NC}"
                if [ "$VERBOSE" = true ]; then
                    echo -e "   Server version: $REDIS_VERSION"
                    echo -e "Command: AUTH ... | PING | nc -w 3 $REDIS_HOST $REDIS_PORT"
                    echo -e "Result: $auth_result"
                fi
                REDIS_RESULT=0
                echo -e ""
            else
                # If netcat fails, try SSH
                if [ "$VERBOSE" = true ]; then
                    echo -e "Netcat test failed, trying SSH..."
                fi
                
                if docker exec ${CONTAINER_ID} which ssh >/dev/null 2>&1; then
                    if run_redis_test_with_ssh "$REDIS_HOST"; then
                        echo -e "${GREEN}✅ Redis connection test: SUCCESS (using SSH)${NC}"
                        if [ "$VERBOSE" = true ]; then
                            echo -e "   Server version: $REDIS_VERSION"
                            echo -e "Command: ssh root@$REDIS_HOST 'nc -w 3 127.0.0.1 $REDIS_PORT'"
                            echo -e "Result: $auth_result"
                        fi
                        REDIS_RESULT=0
                        echo -e ""
                    else
                        echo -e "${RED}❌ Redis connection test: FAILED${NC}"
                        if [ "$VERBOSE" = true ]; then
                            echo -e "Command: AUTH ... | PING | nc -w 3 $REDIS_HOST $REDIS_PORT"
                            echo -e "Result: $auth_result"
                            show_redis_troubleshooting "$REDIS_HOST"
                        fi
                        echo -e ""
                    fi
                else
                    echo -e "${RED}❌ Redis connection test: FAILED (SSH not available in container)${NC}"
                    if [ "$VERBOSE" = true ]; then
                        echo -e "Command: AUTH ... | PING | nc -w 3 $REDIS_HOST $REDIS_PORT"
                        echo -e "Result: $auth_result"
                        show_redis_troubleshooting "$REDIS_HOST"
                    fi
                    echo -e ""
                fi
            fi
        fi
    else
        echo -e "${RED}✗ Redis port $REDIS_PORT is CLOSED or unreachable${NC}"
        if [ "$VERBOSE" = true ]; then
            show_redis_troubleshooting "$REDIS_HOST"
        fi
        echo -e ""
    fi
}

# Test Redis using redis-cli
function run_redis_test_with_cli() {
    local host=$1
    
    # Test Redis connection with redis-cli
    if [ -z "${REDIS_PASSWORD}" ]; then
        # No password
        REDIS_TEST_OUTPUT=$(docker exec ${CONTAINER_ID} redis-cli -h "${host}" -p "${REDIS_PORT}" PING 2>&1)
        if [ "$REDIS_TEST_OUTPUT" = "PONG" ]; then
            REDIS_SERVER_INFO=$(docker exec ${CONTAINER_ID} redis-cli -h "${host}" -p "${REDIS_PORT}" INFO SERVER 2>&1)
            if echo "$REDIS_SERVER_INFO" | grep -q "redis_version"; then
                REDIS_VERSION=$(echo "$REDIS_SERVER_INFO" | grep "redis_version" | cut -d ":" -f2 | tr -d "\r\n ")
            fi
            return 0
        else
            if echo "$REDIS_TEST_OUTPUT" | grep -q "AUTH failed"; then
                # Even with AUTH failed warning, if we get PONG, connection is successful
                if echo "$REDIS_TEST_OUTPUT" | grep -q "PONG"; then
                    REDIS_SERVER_INFO=$(docker exec ${CONTAINER_ID} redis-cli -h "${host}" -p "${REDIS_PORT}" INFO SERVER 2>&1)
                    if echo "$REDIS_SERVER_INFO" | grep -q "redis_version"; then
                        REDIS_VERSION=$(echo "$REDIS_SERVER_INFO" | grep "redis_version" | cut -d ":" -f2 | tr -d "\r\n ")
                    fi
                    return 0
                fi
            fi
            return 1
        fi
    else
        # With password
        REDIS_TEST_OUTPUT=$(docker exec ${CONTAINER_ID} redis-cli -h "${host}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" PING 2>&1)
        if [ "$REDIS_TEST_OUTPUT" = "PONG" ]; then
            REDIS_SERVER_INFO=$(docker exec ${CONTAINER_ID} redis-cli -h "${host}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" INFO SERVER 2>&1)
            if echo "$REDIS_SERVER_INFO" | grep -q "redis_version"; then
                REDIS_VERSION=$(echo "$REDIS_SERVER_INFO" | grep "redis_version" | cut -d ":" -f2 | tr -d "\r\n ")
            fi
            return 0
        else
            if echo "$REDIS_TEST_OUTPUT" | grep -q "AUTH failed"; then
                # If password is required and AUTH failed, connection is not successful
                echo -e "${RED}Redis authentication failed: $REDIS_TEST_OUTPUT${NC}"
            fi
            return 1
        fi
    fi
}

# Test Redis using netcat
function run_redis_test_with_netcat() {
    local host=$1
    
    # Handle cases with and without password
    if [ -z "${REDIS_PASSWORD}" ]; then
        # No password - simple PING test
        REDIS_TEST_OUTPUT=$(docker exec ${CONTAINER_ID} bash -c "echo -e 'PING\r\n' | nc -w 3 ${host} ${REDIS_PORT}" 2>/dev/null)
        # Try to get version info
        REDIS_SERVER_INFO=$(docker exec ${CONTAINER_ID} bash -c "echo -e 'INFO SERVER\r\n' | nc -w 3 ${host} ${REDIS_PORT}" 2>/dev/null)
    else
        # With password - AUTH command followed by PING and INFO
        REDIS_TEST_OUTPUT=$(docker exec ${CONTAINER_ID} bash -c "{ echo -e \"AUTH ${REDIS_PASSWORD}\r\nPING\r\nQUIT\r\n\"; } | nc -w 3 ${host} ${REDIS_PORT}" 2>/dev/null)
        # Try to get version info
        REDIS_SERVER_INFO=$(docker exec ${CONTAINER_ID} bash -c "{ echo -e \"AUTH ${REDIS_PASSWORD}\r\nINFO SERVER\r\nQUIT\r\n\"; } | nc -w 3 ${host} ${REDIS_PORT}" 2>/dev/null)
    fi
    
    # Check for successful PING response
    if echo "$REDIS_TEST_OUTPUT" | grep -q "+PONG"; then
        # Try to extract version from server info
        if echo "$REDIS_SERVER_INFO" | grep -q "redis_version"; then
            REDIS_VERSION=$(echo "$REDIS_SERVER_INFO" | grep "redis_version" | cut -d ":" -f2 | tr -d "\r\n ")
        fi
        echo "$REDIS_TEST_OUTPUT"
        return 0
    else
        echo "$REDIS_TEST_OUTPUT"
        return 1
    fi
}

# Test Redis using SSH
function run_redis_test_with_ssh() {
    local host=$1
    
    # Handle cases with and without password
    if [ -z "${REDIS_PASSWORD}" ]; then
        # No password - simple PING test
        REDIS_TEST_OUTPUT=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -p 22 root@${host} "echo -e 'PING\r\n' | nc -w 3 127.0.0.1 ${REDIS_PORT}" 2>/dev/null)
        # Try to get version info
        REDIS_SERVER_INFO=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -p 22 root@${host} "echo -e 'INFO SERVER\r\n' | nc -w 3 127.0.0.1 ${REDIS_PORT}" 2>/dev/null)
    else
        # With password - AUTH command followed by PING and INFO
        REDIS_TEST_OUTPUT=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -p 22 root@${host} "{ echo -e \"AUTH ${REDIS_PASSWORD}\r\nPING\r\nQUIT\r\n\"; } | nc -w 3 127.0.0.1 ${REDIS_PORT}" 2>/dev/null)
        # Try to get version info
        REDIS_SERVER_INFO=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -p 22 root@${host} "{ echo -e \"AUTH ${REDIS_PASSWORD}\r\nINFO SERVER\r\nQUIT\r\n\"; } | nc -w 3 127.0.0.1 ${REDIS_PORT}" 2>/dev/null)
    fi
    
    # Check for successful PING response
    if echo "$REDIS_TEST_OUTPUT" | grep -q "+PONG"; then
        # Try to extract version from server info
        if echo "$REDIS_SERVER_INFO" | grep -q "redis_version"; then
            REDIS_VERSION=$(echo "$REDIS_SERVER_INFO" | grep "redis_version" | cut -d ":" -f2 | tr -d "\r\n ")
        fi
        echo "$REDIS_TEST_OUTPUT"
        return 0
    else
        echo "$REDIS_TEST_OUTPUT"
        return 1
    fi
}

# Show Redis troubleshooting info
function show_redis_troubleshooting() {
    local host=$1
    
    echo -e "\nRedis Troubleshooting:"
    echo "1. Check if the Redis server is running on ${host}:${REDIS_PORT}"
    echo "2. If using a password, verify it is correct"
    echo "3. Make sure Redis allows external connections (bind to 0.0.0.0)"
    echo "4. Check if protected-mode is set to 'no' in redis.conf"
    echo "5. If using 'host.docker.internal', make sure your Docker version supports it"
}

# =============================================================================
# Result Summary Functions
# =============================================================================

function show_summary() {
    local all_passed=true

    echo -e "\n${BLUE}===== SUMMARY =====${NC}\n"

    if [ $LOCAL_MYSQL_RESULT -eq 0 ] && [ $LOCAL_REDIS_RESULT -eq 0 ] && [ $MYSQL_RESULT -eq 0 ] && [ $REDIS_RESULT -eq 0 ]; then
        echo -e "${GREEN}All connection tests PASSED!${NC}"
    else
        echo -e "${RED}Some connection tests FAILED!${NC}"
        all_passed=false
    fi

    return $([ "$all_passed" = true ] && echo 0 || echo 1)
}

# =============================================================================
# Main Execution
# =============================================================================

function main() {
    process_args "$@"
    load_env_vars

    echo -e "\n${BLUE}====== QUERYPIE SCANNING ======${NC}\n"

    # Set up Docker container if not already specified
    if [ -z "$CONTAINER_ID" ]; then
        setup_docker_container
    fi

    # First check Docker container resources if in verbose mode
    if [ "$VERBOSE" = true ]; then
        check_container_resources
    fi

    # Local scanning section
    echo -e "${BLUE}===== Local Scanning =====${NC}"
    
    # Test MySQL connection locally
    echo -e "Testing MySQL Connection (Local)..."
    test_mysql_local
    
    # Test Redis connection locally
    echo -e "Testing Redis Connection (Local)..."
    test_redis_local
    
    # Instance scanning section
    echo -e "\n${BLUE}===== Instance Scanning =====${NC}"
    
    # Test MySQL connection from Docker container
    echo -e "\nTesting MySQL Connection (Instance)..."
    test_mysql_connection
    
    # Test Redis connection from Docker container
    echo -e "\nTesting Redis Connection (Instance)..."
    test_redis_connection
    
    # Show summary
    show_summary
    exit $?
}

# Process command line arguments
parse_arguments "$@"

# Load environment variables
load_environment_variables

# Show test start message
log_info "\n====== QUERYPIE SCANNING ======\n"

# Test MySQL connections
log_info "Testing MySQL Connection (Local)..."
test_mysql_local
LOCAL_MYSQL_RESULT=$?

# Test Redis connections
log_info "Testing Redis Connection (Local)..."
test_redis_local
LOCAL_REDIS_RESULT=$?

# Setup Docker container for additional tests
setup_docker_container

# Check container resources
check_container_resources

# Run MySQL test in Docker
log_info "Testing MySQL Connection (Instance)..."
test_mysql_connection
MYSQL_RESULT=$?

# Run Redis test in Docker
log_info "Testing Redis Connection (Instance)..."
test_redis_connection
REDIS_RESULT=$?

# Show overall test result summary
show_summary