#!/bin/bash

# merge-env.sh - Configuration file comparison and merge script
# Created: March 5, 2025 18:42:30
# 
# Usage: ./merge-env.sh <previous_version> [--dry-run] [-y] | undo

#######################################
# Initial setup and error checking
#######################################

# Usage check
if [ $# -lt 1 ]; then
    echo "Usage: $0 <previous_version> [--dry-run] [-y] | undo"
    echo "  <previous_version>  Version number in major.minor.patch format (e.g., 10.2.4)"
    echo "  --dry-run          Display comparison results without making changes"
    echo "  -y                 Auto-confirm all operations (ignored in dry-run mode)"
    echo "  undo               Restore from backup file"
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
    echo -e "${GREEN}✅  compose-env file has been restored from backup${NC}"
    echo -e "${YELLOW}⚠️  Note: Other files (certs, novac-compose.yml, skip_command_config.json) need to be restored manually from their respective backups${NC}"
    exit 0
fi

# Initialize flags
DRY_RUN=false
AUTO_CONFIRM=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -y)
            AUTO_CONFIRM=true
            shift
            ;;
        -dry-run|-dryrun|-d)
            echo "Error: Invalid option format. Use '--dry-run' instead of '$1'"
            exit 1
            ;;
        -*)
            echo "Error: Unknown option '$1'"
            echo "Valid options are: --dry-run, -y"
            exit 1
            ;;
        *)
            if [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "Error: Invalid version format. Please use major.minor.patch format (e.g., 10.2.4)"
                exit 1
            fi
            VERSION=$1
            shift
            ;;
    esac
done

# If in dry-run mode, ignore auto-confirm flag
if [ "$DRY_RUN" = true ]; then
    AUTO_CONFIRM=false
fi

# File definitions
ORIGINAL_DIR="../$VERSION"
ORIGINAL_FILE="$ORIGINAL_DIR/compose-env"
NEW_FILE="./compose-env"
OUTPUT_FILE="$NEW_FILE"
SIMPLE_BACKUP="$NEW_FILE.backup"
BACKUP_FILE="$NEW_FILE.backup_$(date +%Y%m%d%H%M%S)"

# Check if original directory exists
if [ ! -d "$ORIGINAL_DIR" ]; then
    echo "Error: Directory '$ORIGINAL_DIR' not found."
    exit 1
fi

# Check if compose-env exists in original directory
if [ ! -f "$ORIGINAL_FILE" ]; then
    echo "Error: compose-env file not found in '$ORIGINAL_DIR'"
    exit 1
fi

# Check if compose-env exists in current directory
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
# New functions for file operations
#######################################

# Function to get user confirmation
get_confirmation() {
    local message=$1
    local operation=$2
    
    # Auto-confirm if auto-confirm mode is enabled
    if [ "$AUTO_CONFIRM" = true ]; then
        echo -e "\n${YELLOW}$message${NC}"
        echo -e "${GREEN}Auto-confirming (yes mode)${NC}"
        return 0
    fi
    
    echo -e "\n${YELLOW}$message${NC}"
    read -p "Do you want to proceed? (y/Enter for yes, any other key for no): " response
    if [[ "$response" =~ ^[yY]$ ]] || [[ -z "$response" ]]; then
        return 0
    else
        echo -e "${RED}Operation cancelled: $operation${NC}"
        return 1
    fi
}

# Function to backup and copy file
backup_and_copy() {
    local src=$1
    local dst=$2
    local backup_ext=".backup_$(date +%Y%m%d%H%M%S)"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n${BLUE}Would copy:${NC}"
        echo "From: $src"
        echo "To: $dst"
        echo "Backup would be: ${dst}${backup_ext}"
        return 0
    fi
    
    if get_confirmation "Copy $src to $dst" "Copying $src to $dst"; then
        if [ -f "$dst" ]; then
            cp "$dst" "${dst}${backup_ext}"
            echo -e "${GREEN}Created backup: ${dst}${backup_ext}${NC}"
        fi
        cp "$src" "$dst"
        echo -e "${GREEN}Successfully copied $src to $dst${NC}\n"
        return 0
    else
        return 1
    fi
}

# Function to handle certs directory
handle_certs_directory() {
    local src_certs="$ORIGINAL_DIR/certs"
    local dst_certs="./certs"
    local timestamp=$(date +%Y%m%d%H%M%S)
    
    # Always show the confirmation message first
    echo -e "\n${YELLOW}⚙️  About to handle certs directory${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}Would handle certs directory:${NC}"
        echo "From: $src_certs"
        echo "To: $dst_certs"
        if [ -d "$src_certs" ]; then
            echo "Contents of source certs directory:"
            ls -la "$src_certs"
        fi
        return 0
    fi
    
    # Check if source certs directory exists and is not empty
    if [ ! -d "$src_certs" ] || [ -z "$(ls -A $src_certs)" ]; then
        echo -e "${YELLOW}Source certs directory is empty or does not exist: $src_certs${NC}"
        echo -e "${YELLOW}Skipping certs directory handling${NC}\n"
        return 0
    fi
    
    if get_confirmation "Copy certs from $src_certs to $dst_certs" "Copying certs directory"; then
        # Create certs directory if it doesn't exist
        if [ ! -d "$dst_certs" ]; then
            mkdir -p "$dst_certs"
            echo -e "${GREEN}Created certs directory: $dst_certs${NC}"
        fi
        
        # Backup existing certs if any
        if [ -d "$dst_certs" ] && [ "$(ls -A $dst_certs)" ]; then
            local backup_dir="${dst_certs}/backup_${timestamp}"
            echo -e "${BLUE}Backing up existing certs:${NC}"
            echo "  - Creating backup directory: $backup_dir"
            mkdir -p "$backup_dir"
            echo "  - Moving existing files to backup"
            # Move only files, not directories
            find "$dst_certs" -maxdepth 1 -type f -exec mv {} "$backup_dir/" \;
            echo -e "${GREEN}  ✓ Backed up existing certs to $backup_dir${NC}"
        fi
        
        # Copy new certs from source
        echo -e "${BLUE}Copying new certs:${NC}"
        echo "  - Source: $src_certs"
        echo "  - Destination: $dst_certs"
        cp -r "$src_certs"/* "$dst_certs/"
        echo -e "${GREEN}  ✓ Successfully copied certs directory${NC}\n"
    else
        echo -e "${YELLOW}Skipping certs directory handling${NC}\n"
    fi
    return 0
}

# Function to handle configuration files
handle_config_files() {
    local files=("novac-compose.yml" "skip_command_config.json")
    
    for file in "${files[@]}"; do
        local src="$ORIGINAL_DIR/$file"
        local dst="./$file"
        
        # Always show the confirmation message first
        echo -e "\n${YELLOW}⚙️  About to handle $file${NC}"
        
        if [ ! -f "$src" ]; then
            echo -e "${YELLOW}Source file $src not found${NC}\n"
            continue
        fi
        
        # Check file content based on file type
        if [ "$file" = "novac-compose.yml" ]; then
            if [ ! -s "$src" ]; then
                echo -e "${YELLOW}Source file $src is empty${NC}"
                echo -e "${YELLOW}Skipping $file handling${NC}\n"
                continue
            fi
        else  # skip_command_config.json
            if [ ! -s "$src" ] || [ "$(cat "$src" | tr -d ' \n\t')" = "{}" ]; then
                echo -e "${YELLOW}Source file $src is empty or contains only {}${NC}"
                echo -e "${YELLOW}Skipping $file handling${NC}\n"
                continue
            fi
        fi
        
        backup_and_copy "$src" "$dst"
    done
}

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

# First check if there are any removed keys
REMOVED_COUNT=0
while IFS= read -r key; do
    if ! grep -q "^$key$" "$KEYS_NEW"; then
        # Get original value
        original_line=$(grep -E "^$key=" "$ORIGINAL_FILE")
        original_value=$(echo "$original_line" | sed "s/^$key=//")
        # Save removed key
        echo "Key '$key'='$original_value'" >> "$REMOVED_KEYS"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    fi
done < "$KEYS_ORIGINAL"

# Only add removed keys section if there are any
if [ $REMOVED_COUNT -gt 0 ]; then
    echo "" >> "$MERGED_FILE"
    echo "# Removed keys" >> "$MERGED_FILE"
    
    # Process again to add to the file
    while IFS= read -r key; do
        if ! grep -q "^$key$" "$KEYS_NEW"; then
            original_line=$(grep -E "^$key=" "$ORIGINAL_FILE")
            echo "# $original_line" >> "$MERGED_FILE"
        fi
    done < "$KEYS_ORIGINAL"
fi

#######################################
# Create result file
#######################################

# Create final result file (only if not in dry run mode)
if [ "$DRY_RUN" = false ]; then
    cp "$MERGED_FILE" "$OUTPUT_FILE"
    echo -e "${GREEN}✅  Starting merge process. Files will be modified.${NC}\n"
    echo "Result file: $OUTPUT_FILE"
else
    echo -e "${YELLOW}🔍  Dry run mode: Output shows comparison results only, no changes made.${NC}\n"
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
echo -e "${BLUE}===== Key Comparison Results =====${NC}"
echo "Original file: $ORIGINAL_FILE"
echo "New file: $NEW_FILE"

print_category "$UNCHANGED_KEYS" "$BLUE" "Unchanged Keys"
print_category "$FILLED_KEYS" "$BLUE" "Keys Filled with Original Values"
print_category "$CHANGED_KEYS" "$YELLOW" "Changed Keys"
print_category "$NEW_KEYS" "$GREEN" "New Keys"
print_category "$REMOVED_KEYS" "$RED" "Removed Keys"

echo ""
if [ "$DRY_RUN" = false ]; then
    echo -e "${GREEN}✅  Key comparison complete. Proceeding with file operations.${NC}"
else
    echo -e "${YELLOW}🔍  Dry run analysis complete. No actual files were changed.${NC}"
fi

#######################################
# Cleanup
#######################################

# Remove temporary directory
rm -rf "$TEMP_DIR"

# Handle certs directory and configuration files
echo -e "\n${BLUE}===== File Operations =====${NC}"
handle_certs_directory
handle_config_files

# Final success message
if [ "$DRY_RUN" = false ]; then
    echo -e "${GREEN}✅  All operations completed successfully${NC}"
fi
