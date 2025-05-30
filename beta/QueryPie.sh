#!/bin/bash
#
# Author: skipper
# Created: 2025-04-03
#

# Show help message
show_help() {
    echo "Usage: $0 <service> <version> <action> [<subaction>] [<filename>]"
    echo
    echo "Parameters:"
    echo "  service   : Service to manage (querypie or tools)"
    echo "  version   : Version in format major.minor.patch (e.g., 1.0.0)"
    echo "  action    : Action to perform (up, down, restart, log, or license)"
    echo "  subaction : Subaction for license (upload or list)"
    echo "  filename  : License file name (required only for 'license upload' action)"
    echo
    echo "Examples:"
    echo "  $0 querypie 1.0.0 up"
    echo "  $0 tools 1.0.0 down"
    echo "  $0 querypie 1.0.0 restart"
    echo "  $0 querypie 1.0.0 log"
    echo "  $0 tools 1.0.0 log"
    echo "  $0 querypie 1.0.0 license upload license.crt"
    echo "  $0 querypie 1.0.0 license list"
    echo
    echo "Options:"
    echo "  -h        : Show this help message"
    exit 0
}

# Check for help option
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

# Check if correct number of arguments are provided
if [ "$#" -eq 5 ]; then
    # For license upload action
    if [ "$3" = "license" ] && [ "$4" = "upload" ]; then
        SERVICE=$1
        VERSION=$2
        ACTION=$3
        LICENSE_SUBACTION=$4
        LICENSE_FILE=$5
    else
        echo "Error: Invalid arguments"
        echo "Use '$0 -h' for help"
        exit 1
    fi
elif [ "$#" -eq 4 ]; then
    # For license list action
    if [ "$3" = "license" ]; then
        SERVICE=$1
        VERSION=$2
        ACTION=$3
        LICENSE_SUBACTION=$4
        if [ "$LICENSE_SUBACTION" != "list" ]; then
            echo "Error: Invalid license subaction. Must be 'list' or 'upload'"
            echo "Use '$0 -h' for help"
            exit 1
        fi
    else
        echo "Error: Invalid arguments"
        echo "Use '$0 -h' for help"
        exit 1
    fi
elif [ "$#" -eq 3 ]; then
    # Standard actions or default license list action
    SERVICE=$1
    VERSION=$2
    ACTION=$3
    # If action is license and no subaction is provided, assume it's a list operation
    if [ "$ACTION" = "license" ]; then
        LICENSE_SUBACTION="list"
    fi
else
    echo "Error: Invalid number of arguments"
    echo "Use '$0 -h' for help"
    exit 1
fi

# Store the original directory
ORIGINAL_DIR=$(pwd)

# Validate service parameter
if [ "$SERVICE" != "querypie" ] && [ "$SERVICE" != "tools" ]; then
    echo "Error: Service must be either 'querypie' or 'tools'"
    echo "Use '$0 -h' for help"
    exit 1
fi

# Validate version format
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format major.minor.patch"
    echo "Use '$0 -h' for help"
    exit 1
fi

# Validate action parameter
if [ "$ACTION" != "up" ] && [ "$ACTION" != "down" ] && [ "$ACTION" != "restart" ] && [ "$ACTION" != "log" ] && [ "$ACTION" != "license" ]; then
    echo "Error: Action must be either 'up', 'down', 'restart', 'log', or 'license'"
    echo "Use '$0 -h' for help"
    exit 1
fi

# Check if license file exists when action is license and subaction is upload
if [ "$ACTION" = "license" ] && [ "$LICENSE_SUBACTION" = "upload" ]; then
    if [ ! -f "$LICENSE_FILE" ]; then
        echo "Error: License file '$LICENSE_FILE' does not exist"
        exit 1
    fi
fi

# Change to the version directory
TARGET_DIR="./querypie/$VERSION"
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory $TARGET_DIR does not exist"
    exit 1
fi

cd "$TARGET_DIR"

# Check if compose-env file exists
if [ ! -f "compose-env" ]; then
    echo "Error: compose-env file not found in $TARGET_DIR"
    cd "$ORIGINAL_DIR"
    exit 1
fi

# Execute the requested action
case $ACTION in
    "up")
        docker-compose --env-file compose-env --profile "$SERVICE" up -d
        if [ "$SERVICE" = "querypie" ]; then
            echo "Showing logs for querypie-app-1..."
            docker logs -f querypie-app-1
        fi
        ;;
    "down")
        docker-compose --env-file compose-env --profile "$SERVICE" down
        ;;
    "restart")
        docker-compose --env-file compose-env --profile "$SERVICE" down
        docker-compose --env-file compose-env --profile "$SERVICE" up -d
        if [ "$SERVICE" = "querypie" ]; then
            echo "Showing logs for querypie-app-1..."
            docker logs -f querypie-app-1
        fi
        ;;
    "log")
        if [ "$SERVICE" = "querypie" ]; then
            echo "Showing logs for querypie-app-1..."
            docker logs -f querypie-app-1
        else
            echo "Showing logs for querypie-tools-1..."
            docker logs -f querypie-tools-1
        fi
        ;;
    "license")
        # Check if tools container is already running
        if docker ps | grep -q "querypie-tools-1"; then
            echo "Tools service is already running..."
            TOOLS_ALREADY_RUNNING=true
        else
            echo "Starting tools service..."
            docker-compose --env-file compose-env --profile tools up -d

            # Wait for 10 seconds only if we just started the tools
            echo "Waiting for 10 seconds for tools to start..."
            sleep 10
            TOOLS_ALREADY_RUNNING=false
        fi

        # Return to original directory
        cd "$ORIGINAL_DIR"

        # Check license subaction
        if [ "$LICENSE_SUBACTION" = "list" ]; then
            # Execute list command
            echo "Executing command: docker exec -it querypie-tools-1 /app/script/license.sh list"
            docker exec -it querypie-tools-1 /app/script/license.sh list
        elif [ "$LICENSE_SUBACTION" = "upload" ]; then
            # Upload license file
            echo "Uploading license file '$LICENSE_FILE'..."
            echo "Executing command: curl -XPOST 127.0.0.1:8050/license/upload -F file=@\"$LICENSE_FILE\""
            curl -XPOST 127.0.0.1:8050/license/upload -F file=@"$LICENSE_FILE"
        fi

        # Ask for confirmation to continue if we started the tools service
        if [ "$TOOLS_ALREADY_RUNNING" = "false" ]; then
            echo
            read -p "Continue with stopping tools service? (y/[Enter] to continue, any other key to exit): " CONTINUE
            if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "" ]; then
                echo "Exiting without stopping tools service."
                exit 0
            fi

            # Navigate back to version directory
            cd "$TARGET_DIR"

            # Stop tools service
            echo "Stopping tools service..."
            docker-compose --env-file compose-env --profile tools down
        fi
        ;;
esac

# Return to the original directory
cd "$ORIGINAL_DIR" 
