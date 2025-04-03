#!/bin/bash
#
# Author: skipper
# Created: 2025-04-03
#

# Show help message
show_help() {
    echo "Usage: $0 <service> <version> <action>"
    echo
    echo "Parameters:"
    echo "  service   : Service to manage (querypie or tools)"
    echo "  version   : Version in format major.minor.patch (e.g., 1.0.0)"
    echo "  action    : Action to perform (up, down, restart, or log)"
    echo
    echo "Examples:"
    echo "  $0 querypie 1.0.0 up"
    echo "  $0 tools 1.0.0 down"
    echo "  $0 querypie 1.0.0 restart"
    echo "  $0 querypie 1.0.0 log"
    echo "  $0 tools 1.0.0 log"
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
if [ "$#" -ne 3 ]; then
    echo "Error: Invalid number of arguments"
    echo "Use '$0 -h' for help"
    exit 1
fi

# Get parameters
SERVICE=$1
VERSION=$2
ACTION=$3

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
if [ "$ACTION" != "up" ] && [ "$ACTION" != "down" ] && [ "$ACTION" != "restart" ] && [ "$ACTION" != "log" ]; then
    echo "Error: Action must be either 'up', 'down', 'restart', or 'log'"
    echo "Use '$0 -h' for help"
    exit 1
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
esac

# Return to the original directory
cd "$ORIGINAL_DIR" 