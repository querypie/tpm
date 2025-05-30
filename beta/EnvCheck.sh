#!/bin/bash

# EnvCheck.sh
# This script displays all environment variables used in Docker Compose
# by parsing compose-env and docker-compose.yml files.
#
# Usage: ./EnvCheck.sh [version] [-o|--output [filename]]
#   version: Optional. If provided, checks files in ./querypie/version/ directory
#            Looks for docker-compose.yml or novac-compose.yml in the version directory
#            If the script is run from a directory with the same name as the version parameter
#            and the required files exist in that directory, it will use those files instead
#   -o, --output: Optional. If provided, saves output to a file while also displaying on screen
#                 If no filename is provided with -o, uses default filename with timestamp

# Set colors for better readability
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display usage information
display_usage() {
    echo "Usage: $0 [version] [-o|--output [filename]] [-h|--help]"
    echo "  version: Optional. If provided, checks files in ./querypie/version/ directory"
    echo "           Looks for docker-compose.yml or novac-compose.yml in the version directory"
    echo "           If the script is run from a directory with the same name as the version parameter"
    echo "           and the required files exist in that directory, it will use those files instead"
    echo "  -o, --output: Optional. If provided, saves output to a file while also displaying on screen"
    echo "                If no filename is provided with -o, uses default filename with timestamp"
    echo "  -h, --help: Display this help message and exit"
    exit 0
}

# Default values
VERSION=""
OUTPUT_FILE=""
SHOW_SENSITIVE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Display usage if no arguments are provided
if [[ $# -eq 0 ]]; then
    display_usage
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            display_usage
            ;;
        -s)
            SHOW_SENSITIVE=true
            shift
            ;;
        -o|--output)
            if [[ -n "$2" && "$2" != -* ]]; then
                OUTPUT_FILE="$2"
                shift 2
            else
                # If no filename is provided, use default with timestamp
                TIMESTAMP=$(date +"%Y%m%d%H%M%S")
                OUTPUT_FILE="env_check_${TIMESTAMP}.txt"
                shift
            fi
            ;;
        -o=*|--output=*)
            OUTPUT_FILE="${1#*=}"
            shift
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Usage: $0 [version] [-o|--output [filename]] [-h|--help]"
            exit 1
            ;;
        *)
            VERSION="$1"
            shift
            ;;
    esac
done

# Set up file paths
if [[ -n "$VERSION" ]]; then
    # Get current directory name
    CURRENT_DIR=$(basename "$(pwd)")

    # Check if current directory name matches the version parameter and contains the required files
    if [[ "$CURRENT_DIR" == "$VERSION" && -f "compose-env" && (-f "docker-compose.yml" || -f "novac-compose.yml") ]]; then
        echo -e "${GREEN}Found required files in current directory ${CURRENT_DIR}${NC}"
        COMPOSE_ENV="$(pwd)/compose-env"

        if [ -f "docker-compose.yml" ]; then
            DOCKER_COMPOSE="$(pwd)/docker-compose.yml"
        else
            DOCKER_COMPOSE="$(pwd)/novac-compose.yml"
        fi
    else
        # Check if version directory exists
        # First try to find the version directory in the script directory
        VERSION_DIR="${SCRIPT_DIR}/querypie/${VERSION}"
        if [ ! -d "$VERSION_DIR" ]; then
            # If not found, try to find it in the parent directory
            VERSION_DIR="${BASE_DIR}/querypie/${VERSION}"
            if [ ! -d "$VERSION_DIR" ]; then
                echo -e "${RED}Error: Directory ${VERSION_DIR} not found${NC}"
                exit 1
            fi
        fi

        COMPOSE_ENV="${VERSION_DIR}/compose-env"

        # Try to find docker-compose.yml or novac-compose.yml
        if [ -f "${VERSION_DIR}/docker-compose.yml" ]; then
            DOCKER_COMPOSE="${VERSION_DIR}/docker-compose.yml"
        elif [ -f "${VERSION_DIR}/novac-compose.yml" ]; then
            DOCKER_COMPOSE="${VERSION_DIR}/novac-compose.yml"
        else
            # If neither file is found in the version directory, use the one from Env-Check
            DOCKER_COMPOSE="${SCRIPT_DIR}/docker-compose.yml"
            echo -e "${YELLOW}Warning: No docker-compose.yml or novac-compose.yml found in ${VERSION_DIR}${NC}"
            echo -e "${YELLOW}Using ${DOCKER_COMPOSE} instead${NC}"
        fi
    fi
else
    COMPOSE_ENV="${SCRIPT_DIR}/compose-env"
    DOCKER_COMPOSE="${SCRIPT_DIR}/docker-compose.yml"
fi

# Check if files exist
if [ ! -f "$COMPOSE_ENV" ]; then
    echo -e "${RED}Error: compose-env file not found at ${COMPOSE_ENV}${NC}"
    exit 1
fi

if [ ! -f "$DOCKER_COMPOSE" ]; then
    echo -e "${RED}Error: No docker-compose file found at ${DOCKER_COMPOSE}${NC}"
    exit 1
fi

# If -s option is used, disable file output
if [[ "$SHOW_SENSITIVE" = true && -n "$OUTPUT_FILE" ]]; then
    echo -e "${YELLOW}Warning: -s option is used, output will not be saved to a file${NC}"
    OUTPUT_FILE=""
fi

# Set up output redirection if output file is specified
if [[ -n "$OUTPUT_FILE" ]]; then
    # Create a temporary file descriptor for tee
    exec 3>&1
    # Redirect stdout to tee which writes to both the file and fd 3 (original stdout)
    exec 1> >(tee "$OUTPUT_FILE" >&3)
    echo -e "${GREEN}Output will be saved to ${OUTPUT_FILE}${NC}"
fi

if [[ -n "$VERSION" ]]; then
    echo -e "${BLUE}=== QueryPie Docker Environment Variables (Version: $VERSION) ===${NC}"
else
    echo -e "${BLUE}=== QueryPie Docker Environment Variables (docker-compose.yml) ===${NC}"
fi
echo

# Parse compose-env file to get user-defined variables
echo -e "${GREEN}Loading variables from ${COMPOSE_ENV}...${NC}"

# Store user-defined variables
declare -a env_keys
declare -a env_values

# Parse compose-env file
while IFS= read -r line; do
    # Skip comments and empty lines
    if [[ ! "$line" =~ ^[[:space:]]*# && ! "$line" =~ ^[[:space:]]*$ ]]; then
        # Extract key and value
        key=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2-)
        env_keys+=("$key")
        env_values+=("$value")
    fi
done < "$COMPOSE_ENV"

# Function to get value for a key
get_env_value() {
    local key="$1"
    local i
    for i in "${!env_keys[@]}"; do
        if [ "${env_keys[$i]}" = "$key" ]; then
            echo "${env_values[$i]}"
            return 0
        fi
    done
    echo ""
    return 1
}

# Function to extract actual default value
extract_default_value() {
    local default_str="$1"
    local depth="$2"

    # Prevent infinite recursion
    if [[ -z "$depth" ]]; then
        depth=0
    elif [[ $depth -gt 5 ]]; then
        echo "$default_str"
        return
    fi

    # Handle simple default values (no variable references)
    if [[ ! "$default_str" =~ \$\{ ]]; then
        echo "$default_str"
        return
    fi

    # Handle multi-level nested variables with default values
    # Pattern: ${VAR1:-${VAR2:-default}}
    if [[ "$default_str" =~ \${([^:}]+):-\${([^:}]+):-([^}]*)} ]]; then
        local outer_var="${BASH_REMATCH[1]}"
        local inner_var="${BASH_REMATCH[2]}"
        local final_default="${BASH_REMATCH[3]}"

        local outer_value=$(get_env_value "$outer_var")
        if [[ -n "$outer_value" ]]; then
            echo "$outer_value"
            return
        fi

        local inner_value=$(get_env_value "$inner_var")
        if [[ -n "$inner_value" ]]; then
            echo "$inner_value"
            return
        fi

        echo "$final_default"
        return
    fi

    # Handle variable references with default values
    if [[ "$default_str" =~ \${([^:}]+):-([^}]*)} ]]; then
        local inner_var="${BASH_REMATCH[1]}"
        local inner_default="${BASH_REMATCH[2]}"

        local inner_value=$(get_env_value "$inner_var")
        if [[ -n "$inner_value" ]]; then
            echo "$inner_value"
        else
            # Recursively resolve the inner default if it contains variable references
            if [[ "$inner_default" =~ \$\{ ]]; then
                extract_default_value "$inner_default" $((depth+1))
            else
                echo "$inner_default"
            fi
        fi
        return
    fi

    # Handle specific pattern for file upload size limits
    # Pattern: ${ENG_FILE_UPLOAD_SIZE_LIMIT_MB:-10}
    if [[ "$default_str" =~ \${ENG_FILE_UPLOAD_SIZE_LIMIT_MB:-([0-9]+)} ]]; then
        local file_size_default="${BASH_REMATCH[1]}"
        echo "$file_size_default"
        return
    fi

    # Handle incomplete variable references with default values
    # Pattern: ${VAR1:-${VAR2
    if [[ "$default_str" =~ \${([^:}]+):-\${([^:}]+) ]]; then
        local outer_var="${BASH_REMATCH[1]}"
        local inner_var="${BASH_REMATCH[2]}"

        local outer_value=$(get_env_value "$outer_var")
        if [[ -n "$outer_value" ]]; then
            echo "$outer_value"
            return
        fi

        local inner_value=$(get_env_value "$inner_var")
        if [[ -n "$inner_value" ]]; then
            echo "$inner_value"
            return
        fi

        # Special case for ENG_FILE_UPLOAD_SIZE_LIMIT_MB
        if [[ "$inner_var" == "ENG_FILE_UPLOAD_SIZE_LIMIT_MB" ]]; then
            echo "10"
            return
        fi

        echo "$default_str"
        return
    fi

    # Handle incomplete variable references (missing closing brace)
    if [[ "$default_str" =~ \${([^:}]+) ]]; then
        local inner_var="${BASH_REMATCH[1]}"
        local inner_value=$(get_env_value "$inner_var")

        if [[ -n "$inner_value" ]]; then
            echo "$inner_value"
        else
            echo "$default_str"
        fi
        return
    fi

    # If we can't parse it, return as is
    echo "$default_str"
}

# Function to resolve variable values
resolve_value() {
    local var_ref="$1"
    local default_value=""
    local error_msg=""

    # Handle incomplete variable references (missing closing brace)
    if [[ "$var_ref" =~ \${([^:}]+)$ ]]; then
        var_name="${BASH_REMATCH[1]}"
        local env_value=$(get_env_value "$var_name")

        if [[ -n "$env_value" ]]; then
            echo "$env_value"
        else
            echo ""
        fi
        return
    fi

    # Special case for file upload size limit variables
    if [[ "$var_ref" =~ \${([A-Z_]+)_FILE_UPLOAD_SIZE_LIMIT_MB:-\${ENG_FILE_UPLOAD_SIZE_LIMIT_MB:-([0-9]+)}} ]]; then
        # This is a file upload size limit variable with a nested default
        echo "${BASH_REMATCH[2]}"
        return
    fi

    # Extract variable name, default value, and error message
    if [[ "$var_ref" =~ \${([^:}]+):?([^}]*)} ]]; then
        var_name="${BASH_REMATCH[1]}"

        # Check if there's a default value or error message
        if [[ "${BASH_REMATCH[2]}" == \?* ]]; then
            error_msg="${BASH_REMATCH[2]:1}"
        elif [[ "${BASH_REMATCH[2]}" == \-* ]]; then
            default_value="${BASH_REMATCH[2]:1}"

            # Try to extract the actual default value
            actual_default=$(extract_default_value "$default_value")
            if [[ "$actual_default" != "$default_value" ]]; then
                default_value="$actual_default"
            fi
        fi

        # Get the value from env_vars
        local env_value=$(get_env_value "$var_name")

        # Return the value, or default, or "REQUIRED"
        if [[ -n "$env_value" ]]; then
            echo "$env_value"
        elif [[ -n "$default_value" ]]; then
            echo "$default_value"
        elif [[ -n "$error_msg" ]]; then
            echo "REQUIRED ($error_msg)"
        else
            echo ""
        fi
    else
        # Return the literal value if it's not a variable reference
        echo "$var_ref"
    fi
}

# Parse docker-compose file to extract services and their environment variables
echo -e "${GREEN}Analyzing ${DOCKER_COMPOSE}...${NC}"
echo

# Extract all environment variables directly from docker-compose file
echo -e "${YELLOW}Environment variables defined in ${DOCKER_COMPOSE}:${NC}"
echo

# Use grep to extract all environment variable lines
env_vars=$(grep -o "^[[:space:]]*-[[:space:]]*[A-Z_][A-Z0-9_]*=" "$DOCKER_COMPOSE" | sed 's/^[[:space:]]*-[[:space:]]*//')

# Count unique environment variables
unique_vars=$(echo "$env_vars" | cut -d= -f1 | sort -u)
var_count=$(echo "$unique_vars" | wc -l)
echo -e "${GREEN}Found $var_count unique environment variables in ${DOCKER_COMPOSE}${NC}"
echo

# Display unique variables with their values
echo -e "${YELLOW}Unique environment variables with values:${NC}"
echo
while IFS= read -r var_name; do
    # Find the first occurrence of this variable in docker-compose file
    var_line=$(grep -m 1 "^[[:space:]]*-[[:space:]]*$var_name=" "$DOCKER_COMPOSE" | sed 's/^[[:space:]]*-[[:space:]]*//')

    if [[ "$var_line" =~ ([A-Z_][A-Z0-9_]*)=(.+) ]]; then
        var_name="${BASH_REMATCH[1]}"
        var_ref="${BASH_REMATCH[2]}"

        # Resolve the value
        resolved_value=$(resolve_value "$var_ref")

        # Mask sensitive information (PASSWORD only) unless -s option is used
        if [[ "$SHOW_SENSITIVE" = false && "$var_name" == *"PASSWORD"* ]]; then
            display_value="[Masked]"
        else
            display_value="$resolved_value"
        fi

        # Display with proper indentation
        echo -e "  ${BLUE}$var_name${NC} = $display_value"
    fi
done <<< "$unique_vars"
echo

# We've already displayed the unique variables, so we don't need to process each service separately
# The detailed output by service and category has been removed to make the output more concise

echo -e "${BLUE}=== End of Environment Variables ===${NC}"
