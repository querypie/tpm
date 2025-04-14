#!/bin/bash
#
# QueryPie Scanner - MySQL and Redis Connection Test Tool
# 
# Usage:
#   ./scanner.sh              - Basic execution
#   ./scanner.sh -v           - Verbose mode
#   ./scanner.sh -b           - Basic connection test only (using /dev/tcp)
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
DB_USERNAME=""
DB_PASSWORD=""
DB_CATALOG=""
REDIS_HOST=""
REDIS_PORT=""
REDIS_PASSWORD=""
REDIS_CONNECTION_MODE=""
REDIS_NODES=""

# Test results
LOCAL_MYSQL_RESULT=1
LOCAL_REDIS_RESULT=1
MYSQL_RESULT=1
REDIS_RESULT=1

# Add BASIC_TEST_ONLY variable to global variables section
BASIC_TEST_ONLY=false

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
    echo "  ./scanner.sh -b           - Basic connection test only (using /dev/tcp)"
    echo "  ./scanner.sh <container>  - Specify container ID or name"
    echo "  ./scanner.sh -h           - Show help"
    echo ""
    exit 0
}

# Convert Docker host names to localhost
function convert_docker_host() {
    local host="$1"
    case "${host}" in
        "host.docker.internal"|"localhost")
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

    # Process all arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -b|--basic)
                BASIC_TEST_ONLY=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                if [ -z "$CONTAINER_PARAM" ]; then
                    CONTAINER_PARAM="$1"
                fi
                shift
                ;;
        esac
    done

    if [ "$VERBOSE" = true ]; then
        log_debug "Verbose mode activated"
        if [ "$BASIC_TEST_ONLY" = true ]; then
            log_debug "Basic test only mode activated"
        fi
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
    DB_USERNAME=$(grep "^DB_USERNAME=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    DB_PASSWORD=$(grep "^DB_PASSWORD=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    DB_CATALOG=$(grep "^DB_CATALOG=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    REDIS_HOST=$(grep "^REDIS_HOST=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    REDIS_PORT=$(grep "^REDIS_PORT=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    REDIS_CONNECTION_MODE=$(grep "^REDIS_CONNECTION_MODE=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    REDIS_NODES=$(grep "^REDIS_NODES=" ${COMPOSE_ENV_FILE} | cut -d '=' -f2)
    
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

# Simple connection test using only /dev/tcp
function test_basic_connection() {
    local host=$1
    local port=$2
    local service_type=$3
    local is_local=$4
    
    if $is_local; then
        # Local connection test
        if timeout 3 bash -c "< /dev/tcp/${host}/${port}" 2>/dev/null; then
            echo -e "${GREEN}✓ ${service_type} connection to ${host}:${port} is OPEN (basic connection test)${NC}"
            return 0
        else
            echo -e "${RED}✗ ${service_type} connection to ${host}:${port} is CLOSED or unreachable (basic connection test)${NC}"
            return 1
        fi
    else
        # Docker container connection test
        if docker exec ${CONTAINER_ID} bash -c "timeout 3 bash -c '< /dev/tcp/${host}/${port}'" 2>/dev/null; then
            echo -e "${GREEN}✓ ${service_type} connection to ${host}:${port} is OPEN (basic connection test)${NC}"
            return 0
        else
            echo -e "${RED}✗ ${service_type} connection to ${host}:${port} is CLOSED or unreachable (basic connection test)${NC}"
            return 1
        fi
    fi
}

# Common function to test service connection
function test_service_connection() {
    local host=$1
    local port=$2
    local password=$3
    local service_type=$4  # "MySQL" or "Redis"
    local is_local=$5      # true or false
    local client_type=""
    
    # First try basic connection test
    if ! test_basic_connection "${host}" "${port}" "${service_type}" "${is_local}"; then
        if [ "$VERBOSE" = true ]; then
            show_troubleshooting "${host}" "${port}" "${service_type}"
        fi
        echo -e ""
        return 1
    fi

    # If basic connection succeeds and we don't need detailed testing, we can stop here
    if [ "$BASIC_TEST_ONLY" = "true" ]; then
        echo -e ""
        return 0
    fi
    
    # Set client type based on service type
    if [ "$service_type" = "MySQL" ]; then
        client_type="mysql"
    else
        client_type="redis"
    fi

    # If port is open, proceed with detailed connection tests
    # Test with client
    if test_with_client "${host}" "${port}" "${password}" "${service_type}" "${is_local}"; then
        echo -e "${GREEN}✅ ${service_type} connection test: SUCCESS (using ${client_type} client)${NC}"
        if [ "$VERBOSE" = true ] && [ -n "$SERVICE_VERSION" ]; then
            echo -e "   Server version: $SERVICE_VERSION"
        fi
        echo -e ""
        return 0
    fi

    # Test with netcat
    if [ "$VERBOSE" = true ]; then
        echo -e "${service_type} client failed, trying netcat..."
    fi
    
    if test_with_netcat "${host}" "${port}" "${password}" "${service_type}" "${is_local}"; then
        echo -e "${GREEN}✅ ${service_type} connection test: SUCCESS (using netcat)${NC}"
        if [ "$VERBOSE" = true ] && [ -n "$SERVICE_VERSION" ]; then
            echo -e "   Server version: $SERVICE_VERSION"
            echo -e "Command: nc -w 3 ${host} ${port}"
            echo -e "Server response detected: ${service_type} server is responding"
        fi
        echo -e ""
        return 0
    fi

    echo -e "${RED}❌ ${service_type} connection test: FAILED${NC}"
    if [ "$VERBOSE" = true ]; then
        show_troubleshooting "${host}" "${port}" "${service_type}"
    fi
    echo -e ""
    return 1
}

# Test using client (MySQL client or Redis-cli)
function test_with_client() {
    local host=$1
    local port=$2
    local password=$3
    local service_type=$4
    local is_local=$5
    
    if [ "$service_type" = "MySQL" ]; then
        if $is_local; then
            if ! command -v mysql &>/dev/null; then
                return 1
            fi
            # Local MySQL test
            MYSQL_VERSION=$(mysql \
                -h "${host}" \
                -P "${port}" \
                -u "${DB_USERNAME}" \
                -p"${password}" \
                ${DB_CATALOG:+-D "${DB_CATALOG}"} \
                --protocol=TCP \
                --default-auth=mysql_native_password \
                --ssl \
                -e "SELECT VERSION() as 'MySQL Server Version';" 2>/dev/null | grep -v "MySQL Server Version" | tr -d "\r\n ")
            SERVICE_VERSION=$MYSQL_VERSION
            
            mysql \
                -h "${host}" \
                -P "${port}" \
                -u "${DB_USERNAME}" \
                -p"${password}" \
                ${DB_CATALOG:+-D "${DB_CATALOG}"} \
                --protocol=TCP \
                --default-auth=mysql_native_password \
                --ssl \
                -e "SELECT 'MySQL connection successful!' as Status;" &>/dev/null
            return $?
        else
            # Docker container MySQL test
            if ! docker exec $CONTAINER_ID which mysql &>/dev/null; then
                return 1
            fi
            MYSQL_VERSION=$(docker exec ${CONTAINER_ID} mysql \
                -h "${host}" \
                -P "${port}" \
                -u "${DB_USERNAME}" \
                -p"${password}" \
                ${DB_CATALOG:+-D "${DB_CATALOG}"} \
                --protocol=TCP \
                --default-auth=mysql_native_password \
                --ssl \
                -e "SELECT VERSION() as 'MySQL Server Version';" 2>/dev/null | grep -v "MySQL Server Version" | tr -d "\r\n ")
            SERVICE_VERSION=$MYSQL_VERSION
            
            docker exec ${CONTAINER_ID} mysql \
                -h "${host}" \
                -P "${port}" \
                -u "${DB_USERNAME}" \
                -p"${password}" \
                ${DB_CATALOG:+-D "${DB_CATALOG}"} \
                --protocol=TCP \
                --default-auth=mysql_native_password \
                --ssl \
                -e "SELECT 'MySQL connection successful!' as Status;" &>/dev/null
            return $?
        fi
    else  # Redis
        if $is_local; then
            if ! command -v redis-cli &>/dev/null; then
                return 1
            fi
            # Local Redis test
            if [ -z "${password}" ]; then
                REDIS_TEST_OUTPUT=$(redis-cli -h "${host}" -p "${port}" PING 2>/dev/null)
                REDIS_SERVER_INFO=$(redis-cli -h "${host}" -p "${port}" INFO SERVER 2>/dev/null)
            else
                REDIS_TEST_OUTPUT=$(redis-cli -h "${host}" -p "${port}" -a "${password}" PING 2>/dev/null)
                REDIS_SERVER_INFO=$(redis-cli -h "${host}" -p "${port}" -a "${password}" INFO SERVER 2>/dev/null)
            fi
        else
            # Docker container Redis test
            if ! docker exec $CONTAINER_ID which redis-cli &>/dev/null; then
                return 1
            fi
            if [ -z "${password}" ]; then
                REDIS_TEST_OUTPUT=$(docker exec ${CONTAINER_ID} redis-cli -h "${host}" -p "${port}" PING 2>/dev/null)
                REDIS_SERVER_INFO=$(docker exec ${CONTAINER_ID} redis-cli -h "${host}" -p "${port}" INFO SERVER 2>/dev/null)
            else
                REDIS_TEST_OUTPUT=$(docker exec ${CONTAINER_ID} redis-cli -h "${host}" -p "${port}" -a "${password}" PING 2>/dev/null)
                REDIS_SERVER_INFO=$(docker exec ${CONTAINER_ID} redis-cli -h "${host}" -p "${port}" -a "${password}" INFO SERVER 2>/dev/null)
            fi
        fi
        
        if [ "$REDIS_TEST_OUTPUT" = "PONG" ]; then
            if echo "$REDIS_SERVER_INFO" | grep -q "redis_version"; then
                REDIS_VERSION=$(echo "$REDIS_SERVER_INFO" | grep "redis_version" | cut -d ":" -f2 | tr -d "\r\n ")
                SERVICE_VERSION=$REDIS_VERSION
            fi
            return 0
        fi
        return 1
    fi
}

# Test using netcat
function test_with_netcat() {
    local host=$1
    local port=$2
    local password=$3
    local service_type=$4
    local is_local=$5
    local cmd=""
    local result=""
    
    if [ "$service_type" = "MySQL" ]; then
        cmd="{ 
            sleep 1
            printf '\x4a\x00\x00\x00\x0a'
            printf '8.4.4\x00'
            printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
            printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        } | nc -w 3 ${host} ${port} | tr -d '\0'"
    else  # Redis
        if [ -z "${password}" ]; then
            cmd="echo -e 'PING\r\n' | nc -w 3 ${host} ${port}"
        else
            cmd="{ echo -e \"AUTH ${password}\r\nPING\r\nQUIT\r\n\"; } | nc -w 3 ${host} ${port}"
        fi
    fi
    
    if $is_local; then
        result=$(bash -c "$cmd" 2>/dev/null)
    else
        result=$(docker exec ${CONTAINER_ID} bash -c "$cmd" 2>/dev/null)
    fi
    
    if [ "$service_type" = "MySQL" ]; then
        if echo "$result" | grep -q "mysql\|8\."; then
            SERVICE_VERSION=$(echo "$result" | grep -o -E "([0-9]+\.)+[0-9]+" | head -1)
            return 0
        fi
    else  # Redis
        if echo "$result" | grep -q "+PONG"; then
            # Try to get Redis version
            if [ -z "${password}" ]; then
                cmd="echo -e 'INFO SERVER\r\n' | nc -w 3 ${host} ${port}"
            else
                cmd="{ echo -e \"AUTH ${password}\r\nINFO SERVER\r\nQUIT\r\n\"; } | nc -w 3 ${host} ${port}"
            fi
            
            if $is_local; then
                REDIS_SERVER_INFO=$(bash -c "$cmd" 2>/dev/null)
            else
                REDIS_SERVER_INFO=$(docker exec ${CONTAINER_ID} bash -c "$cmd" 2>/dev/null)
            fi
            
            if echo "$REDIS_SERVER_INFO" | grep -q "redis_version"; then
                SERVICE_VERSION=$(echo "$REDIS_SERVER_INFO" | grep "redis_version" | cut -d ":" -f2 | tr -d "\r\n ")
            fi
            return 0
        fi
    fi
    return 1
}

# Show troubleshooting information
function show_troubleshooting() {
    local host=$1
    local port=$2
    local service_type=$3
    
    echo -e "\n${service_type} Troubleshooting:"
    echo "1. Check if the ${service_type} server is running on ${host}:${port}"
    if [ "$service_type" = "Redis" ]; then
        echo "2. If using a password, verify it is correct"
        echo "3. Make sure Redis allows external connections (bind to 0.0.0.0)"
        echo "4. Check if protected-mode is set to 'no' in redis.conf"
    else  # MySQL
        echo "2. Verify that the user has proper permissions"
        echo "3. Try removing SSL options if you're getting SSL-related errors"
    fi
    if [[ "$host" =~ "host.docker.internal" ]]; then
        echo "5. If using 'host.docker.internal', make sure your Docker version supports it"
    fi
}

# Test MySQL connection from local environment
function test_mysql_local() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}====== TESTING MYSQL CONNECTION FROM LOCAL ENVIRONMENT ======${NC}"
        echo -e "Using MySQL connection info:"
        local converted_host=$(convert_docker_host "$DB_HOST")
        if [ "$converted_host" = "127.0.0.1" ]; then
            echo -e "DB_HOST: ${converted_host} (original: $DB_HOST)"
        else
            echo -e "DB_HOST: ${DB_HOST}"
        fi
        echo -e "DB_PORT: $DB_PORT"
        echo -e "DB_USERNAME: $DB_USERNAME"
        echo -e "DB_CATALOG: $DB_CATALOG"
        echo -e "DB_PASSWORD: ******** (hidden)"
    fi

    test_service_connection "$(convert_docker_host "$DB_HOST")" "$DB_PORT" "$DB_PASSWORD" "MySQL" true
    return $?
}

# Test Redis connection from local environment
function test_redis_local() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}====== TESTING REDIS CONNECTION FROM LOCAL ENVIRONMENT ======${NC}"
        if [ -n "$REDIS_CONNECTION_MODE" ]; then
            echo -e "Using Redis connection info:"
            echo -e "REDIS_CONNECTION_MODE: $REDIS_CONNECTION_MODE"
            echo -e "REDIS_NODES: $REDIS_NODES"
        else
            echo -e "Using Redis connection info:"
            local converted_host=$(convert_docker_host "$REDIS_HOST")
            if [ "$converted_host" = "127.0.0.1" ]; then
                echo -e "REDIS_HOST: ${converted_host} (original: $REDIS_HOST)"
            else
                echo -e "REDIS_HOST: ${REDIS_HOST}"
            fi
            echo -e "REDIS_PORT: $REDIS_PORT"
        fi
        echo -e "REDIS_PASSWORD: ******** (hidden)"
    fi

    # Validate Redis configuration
    if ! validate_redis_config; then
        return 1
    fi

    # Get Redis nodes to test
    local nodes=($(parse_redis_nodes))
    local all_success=true

    for node in "${nodes[@]}"; do
        IFS=':' read -r host port <<< "$node"
        local converted_host=$(convert_docker_host "$host")
        if ! test_service_connection "$converted_host" "$port" "$REDIS_PASSWORD" "Redis" true; then
            all_success=false
        fi
    done

    return $([ "$all_success" = true ] && echo 0 || echo 1)
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

    test_service_connection "$DB_HOST" "$DB_PORT" "$DB_PASSWORD" "MySQL" false
    return $?
}

# Redis configuration validation function
function validate_redis_config() {
    # Check if both old and new configuration styles exist
    if [ -n "$REDIS_HOST" ] && [ -n "$REDIS_PORT" ] && [ -n "$REDIS_CONNECTION_MODE" ]; then
        log_error "Error: Both old (REDIS_HOST/REDIS_PORT) and new (REDIS_CONNECTION_MODE/REDIS_NODES) Redis configurations exist. Please use only one style."
        exit 1
    fi

    # If using new configuration style
    if [ -n "$REDIS_CONNECTION_MODE" ]; then
        # Validate connection mode
        if [ "$REDIS_CONNECTION_MODE" != "STANDALONE" ] && [ "$REDIS_CONNECTION_MODE" != "CLUSTER" ]; then
            log_error "Error: REDIS_CONNECTION_MODE must be either 'STANDALONE' or 'CLUSTER'"
            exit 1
        fi

        # Validate nodes format
        if [ -z "$REDIS_NODES" ]; then
            log_error "Error: REDIS_NODES is required when using REDIS_CONNECTION_MODE"
            exit 1
        fi

        # Parse nodes based on connection mode
        if [ "$REDIS_CONNECTION_MODE" = "STANDALONE" ]; then
            # For standalone, expect single host:port
            if ! [[ "$REDIS_NODES" =~ ^[^:]+:[0-9]+$ ]]; then
                log_error "Error: Invalid REDIS_NODES format for STANDALONE mode. Expected format: host:port"
                exit 1
            fi
        else  # CLUSTER mode
            # For cluster, expect multiple host:port pairs separated by commas
            IFS=',' read -ra NODES <<< "$REDIS_NODES"
            for node in "${NODES[@]}"; do
                if ! [[ "$node" =~ ^[^:]+:[0-9]+$ ]]; then
                    log_error "Error: Invalid node format in REDIS_NODES: $node. Expected format: host:port"
                    exit 1
                fi
            done
        fi
    fi

    return 0
}

# Parse Redis nodes into array
function parse_redis_nodes() {
    local nodes=()
    if [ -n "$REDIS_CONNECTION_MODE" ]; then
        if [ "$REDIS_CONNECTION_MODE" = "STANDALONE" ]; then
            nodes=("$REDIS_NODES")
        else  # CLUSTER mode
            IFS=',' read -ra nodes <<< "$REDIS_NODES"
        fi
    else
        nodes=("$REDIS_HOST:$REDIS_PORT")
    fi
    echo "${nodes[@]}"
}

# Test Redis connection with new configuration
function test_redis_connection() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}====== TESTING REDIS CONNECTION ======${NC}"
        if [ -n "$REDIS_CONNECTION_MODE" ]; then
            echo -e "Using Redis connection info:"
            echo -e "REDIS_CONNECTION_MODE: $REDIS_CONNECTION_MODE"
            echo -e "REDIS_NODES: $REDIS_NODES"
        else
            echo -e "Using Redis connection info:"
            echo -e "REDIS_HOST: $REDIS_HOST"
            echo -e "REDIS_PORT: $REDIS_PORT"
        fi
        echo -e "REDIS_PASSWORD: ******** (hidden)"
    fi

    # Validate Redis configuration
    if ! validate_redis_config; then
        return 1
    fi

    # Get Redis nodes to test
    local nodes=($(parse_redis_nodes))
    local all_success=true

    for node in "${nodes[@]}"; do
        IFS=':' read -r host port <<< "$node"
        if ! test_service_connection "$host" "$port" "$REDIS_PASSWORD" "Redis" false; then
            all_success=false
        fi
    done

    return $([ "$all_success" = true ] && echo 0 || echo 1)
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