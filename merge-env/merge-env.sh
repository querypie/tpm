#!/bin/bash

# merge-env.sh - Configuration file comparison and merge script
# Created: March 5, 2025 18:42:30
# 
# Usage: ./merge-env.sh <original_directory_name> [--dry-run] | undo

#######################################
# Initial setup and error checking
#######################################

# Usage check
if [ $# -lt 1 ]; then
    echo "Usage: $0 <original_directory_name> [--dry-run] | undo"
    echo "  <original_directory_name>  Name of original directory to compare from parent directory"
    echo "  --dry-run                  Display comparison results without making changes"
    echo "  undo                       Restore from backup file"
    exit 1
fi

# Check for undo parameter
if [ "$1" == "undo" ]; then
    BACKUP_FILE="./compose-env.backup"
    
    # Check if backup file exists
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "Error: Backup file '$BACKUP_FILE' does not exist."
        exit 1
    fi
    
    # Restore from backup file
    cp "$BACKUP_FILE" "./compose-env"
    echo "Backup file has been successfully restored."
    exit 0
fi

# Check for dry run mode
DRY_RUN=false
if [ "$1" == "--dry-run" ] && [ $# -eq 2 ]; then
    DRY_RUN=true
    shift
elif [ "$2" == "--dry-run" ]; then
    DRY_RUN=true
fi

# File definitions
ORIGINAL_DIR="../$1"
ORIGINAL_FILE="$ORIGINAL_DIR/compose-env"
NEW_FILE="./compose-env"
OUTPUT_FILE="$NEW_FILE"
SIMPLE_BACKUP="$NEW_FILE.backup"
BACKUP_FILE="$NEW_FILE.backup_$(date +%Y%m%d%H%M%S)"

# Check for files and directories
if [ ! -d "$ORIGINAL_DIR" ]; then
    echo "Error: Directory '$ORIGINAL_DIR' not found."
    exit 1
fi

if [ ! -f "$ORIGINAL_FILE" ]; then
    echo "Error: Original file '$ORIGINAL_FILE' not found."
    exit 1
fi

if [ ! -f "$NEW_FILE" ]; then
    echo "Error: No compose-env file in current directory."
    exit 1
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#######################################
# Temporary file setup
#######################################

# Create temporary directory and files
TEMP_DIR=$(mktemp -d)
MERGED_FILE="$TEMP_DIR/merged.txt"

# Key extraction files
KEYS_ORIGINAL="$TEMP_DIR/keys_original.txt"
KEYS_NEW="$TEMP_DIR/keys_new.txt"

# Result category files
UNCHANGED_KEYS="$TEMP_DIR/unchanged_keys.txt"
CHANGED_KEYS="$TEMP_DIR/changed_keys.txt"
NEW_KEYS="$TEMP_DIR/new_keys.txt"
REMOVED_KEYS="$TEMP_DIR/removed_keys.txt"
FILLED_KEYS="$TEMP_DIR/filled_keys.txt"

# Initialize temporary files
> "$MERGED_FILE"
> "$UNCHANGED_KEYS"
> "$CHANGED_KEYS"
> "$NEW_KEYS"
> "$REMOVED_KEYS"
> "$FILLED_KEYS"

#######################################
# Backup file creation
#######################################

# Only create backups if not in dry run mode
if [ "$DRY_RUN" = false ]; then
    # Simple backup (only on first run)
    if [ ! -f "$SIMPLE_BACKUP" ]; then
        cp "$NEW_FILE" "$SIMPLE_BACKUP"
        echo "Basic backup file created: $SIMPLE_BACKUP"
    fi

    # Timestamp backup (always)
    cp "$NEW_FILE" "$BACKUP_FILE"
    echo "Timestamp backup file created: $BACKUP_FILE"
else
    echo -e "${YELLOW}Dry run mode: No backup files will be created.${NC}"
fi

#######################################
# Key extraction
#######################################

# Extract keys from files (KEY=VALUE format)
grep -E "^[A-Za-z0-9_]+=" "$ORIGINAL_FILE" | sed 's/=.*//' > "$KEYS_ORIGINAL"
grep -E "^[A-Za-z0-9_]+=" "$NEW_FILE" | sed 's/=.*//' > "$KEYS_NEW"

#######################################
# File processing functions
#######################################

# Key/value processing function
process_key_value() {
    local key=$1
    local value=$2
    
    # Check if key exists in original file
    if grep -q "^$key$" "$KEYS_ORIGINAL"; then
        # Get original value
        local original_value=$(grep -E "^$key=" "$ORIGINAL_FILE" | sed "s/^$key=//")
        
        # Check if new value is empty
        if [[ -z "$value" ]]; then
            # Check if original value is also empty
            if [[ -z "$original_value" ]]; then
                # Both empty, keep as is
                echo "$key=" >> "$MERGED_FILE"
                echo "Key '$key' value unchanged (both empty)" >> "$UNCHANGED_KEYS"
            else
                # New value empty, use original value
                echo "$key=$original_value" >> "$MERGED_FILE"
                echo "Key '$key' empty value replaced with original: '$original_value'" >> "$FILLED_KEYS"
            fi
        else
            # Value exists, keep new value
            echo "$key=$value" >> "$MERGED_FILE"
            # Show if different from original
            if [[ "$value" != "$original_value" ]]; then
                echo "Key '$key' value changed: [Original:'$original_value'] -> [New:'$value']" >> "$CHANGED_KEYS"
            else
                echo "Key '$key' value unchanged: '$value'" >> "$UNCHANGED_KEYS"
            fi
        fi
    else
        # New key
        echo "$key=$value" >> "$MERGED_FILE"
        echo "Key '$key'=$value" >> "$NEW_KEYS"
    fi
}

#######################################
# New file processing
#######################################

# Process based on new file
while IFS= read -r line || [[ -n "$line" ]]; do
    # Copy comment lines as is
    if [[ "$line" =~ ^[[:space:]]*# ]]; then
        echo "$line" >> "$MERGED_FILE"
        continue
    fi
    
    # Copy empty lines as is
    if [[ -z "$line" ]]; then
        echo "" >> "$MERGED_FILE"
        continue
    fi
    
    # Check if line is KEY=VALUE format
    if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*) ]]; then
        process_key_value "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    else
        # Copy non-KEY=VALUE lines as is
        echo "$line" >> "$MERGED_FILE"
    fi
done < "$NEW_FILE"

#######################################
# Process removed keys
#######################################

echo "" >> "$MERGED_FILE"
echo "# Removed keys" >> "$MERGED_FILE"

while IFS= read -r key; do
    if ! grep -q "^$key$" "$KEYS_NEW"; then
        # Get original value
        original_line=$(grep -E "^$key=" "$ORIGINAL_FILE")
        original_value=$(echo "$original_line" | sed "s/^$key=//")
        # Save removed key
        echo "Key '$key'='$original_value'" >> "$REMOVED_KEYS"
        # Add as comment to file
        echo "# $original_line" >> "$MERGED_FILE"
    fi
done < "$KEYS_ORIGINAL"

#######################################
# Create result file
#######################################

# Create final result file (only if not in dry run mode)
if [ "$DRY_RUN" = false ]; then
    cp "$MERGED_FILE" "$OUTPUT_FILE"
    echo "File has been updated: $OUTPUT_FILE"
else
    echo -e "${YELLOW}Dry run mode: Output shows comparison results only, no changes made.${NC}"
fi

#######################################
# Output results
#######################################

# Function to print category results
print_category() {
    local file=$1
    local color=$2
    local title=$3
    
    if [ -s "$file" ]; then
        echo ""
        echo -e "${color}[$title]${NC}"
        cat "$file"
    fi
}

# Print summary
echo ""
echo "===== Key Comparison Results ====="
echo "Original file: $ORIGINAL_FILE"
echo "New file: $NEW_FILE"

print_category "$UNCHANGED_KEYS" "$BLUE" "Unchanged Keys"
print_category "$FILLED_KEYS" "$BLUE" "Keys Filled with Original Values"
print_category "$CHANGED_KEYS" "$YELLOW" "Changed Keys"
print_category "$NEW_KEYS" "$GREEN" "New Keys"
print_category "$REMOVED_KEYS" "$RED" "Removed Keys"

echo ""
if [ "$DRY_RUN" = false ]; then
    echo "Processing complete. Result file: $OUTPUT_FILE"
else
    echo "Dry run analysis complete. No actual files were changed."
fi

#######################################
# Cleanup
#######################################

# Remove temporary directory
rm -rf "$TEMP_DIR"
