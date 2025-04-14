#!/bin/bash

# Exit immediately if an error occurs (-e), error on undefined variables (-u)
set -eu

# --- Settings ---
HARBOR_REGISTRY="harbor.chequer.io"
IMAGE_REPO="querypie/querypie"
TOOLS_IMAGE_REPO="querypie/querypie-tools"
TARGET_PLATFORM="linux/amd64" # Specify platform to download
# --- End of Settings ---

# 1. Parameter validation and assignment (version required, app name optional)
if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Error: Invalid number of parameters." >&2
  echo "Usage: $0 <major.minor.patch> [app_name]" >&2
  echo "  - app_name: 'querypie' or 'tools' (optional, processes both if not specified)" >&2
  echo "Example: $0 10.2.1" >&2
  echo "Example: $0 10.2.1 querypie" >&2
  exit 1
fi
VERSION="$1"
# Use 'all' as default if second parameter is not provided
APP_NAME="${2:-all}"

# 2. Version format validation (major.minor.patch)
VERSION_REGEX="^[0-9]+\.[0-9]+\.[0-9]+$"
if [[ ! "$VERSION" =~ $VERSION_REGEX ]]; then
  echo "Error: Invalid version format. Must use 'major.minor.patch' format (e.g., 10.2.1)." >&2
  exit 1
fi

# 3. App name parameter validation (if provided)
if [[ "$APP_NAME" != "all" && "$APP_NAME" != "querypie" && "$APP_NAME" != "tools" ]]; then
  echo "Error: Invalid app name. Use 'querypie' or 'tools' or omit the parameter." >&2
  exit 1
fi
echo "Processing request: Version=${VERSION}, App=${APP_NAME}"
echo "---"

# 4. Define full image paths and output filenames (always define both)
FULL_IMAGE_NAME="${HARBOR_REGISTRY}/${IMAGE_REPO}:${VERSION}"
OUTPUT_FILENAME="querypie-${VERSION}-${TARGET_PLATFORM//\//-}.tar"

FULL_TOOLS_IMAGE_NAME="${HARBOR_REGISTRY}/${TOOLS_IMAGE_REPO}:${VERSION}"
OUTPUT_TOOLS_FILENAME="querypie-tools-${VERSION}-${TARGET_PLATFORM//\//-}.tar"

# 5. Check Docker command and daemon
if ! command -v docker &> /dev/null; then echo "Error: 'docker' command not found..."; exit 1; fi
if ! docker info > /dev/null 2>&1; then echo "Error: Cannot connect to Docker daemon..."; exit 1; fi
echo "Docker environment check completed."
echo "---"

# 6. Set processing flags
PULL_SAVE_MAIN=false
PULL_SAVE_TOOLS=false
TOTAL_STEPS=0

if [[ "$APP_NAME" == "all" || "$APP_NAME" == "querypie" ]]; then
  PULL_SAVE_MAIN=true
  TOTAL_STEPS=$((TOTAL_STEPS + 2)) # Pull + Save
fi
if [[ "$APP_NAME" == "all" || "$APP_NAME" == "tools" ]]; then
  PULL_SAVE_TOOLS=true
  TOTAL_STEPS=$((TOTAL_STEPS + 2)) # Pull + Save
fi

CURRENT_STEP=0

# 7. Image pulling (conditional)
if [[ "$PULL_SAVE_MAIN" == true ]]; then
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo "[${CURRENT_STEP}/${TOTAL_STEPS}] Starting main image pull (${TARGET_PLATFORM}): ${FULL_IMAGE_NAME}"
  if ! docker pull --platform "${TARGET_PLATFORM}" "${FULL_IMAGE_NAME}"; then echo "Error: Main image pull failed..."; exit 1; fi
  echo "Main image pull successful."
  echo "---"
fi
if [[ "$PULL_SAVE_TOOLS" == true ]]; then
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo "[${CURRENT_STEP}/${TOTAL_STEPS}] Starting tools image pull (${TARGET_PLATFORM}): ${FULL_TOOLS_IMAGE_NAME}"
  if ! docker pull --platform "${TARGET_PLATFORM}" "${FULL_TOOLS_IMAGE_NAME}"; then echo "Error: Tools image pull failed..."; exit 1; fi
  echo "Tools image pull successful."
  echo "---"
fi

# 8. Image saving (conditional)
if [[ "$PULL_SAVE_MAIN" == true ]]; then
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo "[${CURRENT_STEP}/${TOTAL_STEPS}] Saving main image: ${OUTPUT_FILENAME}"
  if ! docker save -o "${OUTPUT_FILENAME}" "${FULL_IMAGE_NAME}"; then echo "Error: Main image save failed..."; exit 1; fi
  echo "Main image save successful."
  echo "---"
fi
if [[ "$PULL_SAVE_TOOLS" == true ]]; then
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo "[${CURRENT_STEP}/${TOTAL_STEPS}] Saving tools image: ${OUTPUT_TOOLS_FILENAME}"
  if ! docker save -o "${OUTPUT_TOOLS_FILENAME}" "${FULL_TOOLS_IMAGE_NAME}"; then echo "Error: Tools image save failed..."; exit 1; fi
  echo "Tools image save successful."
  echo "---"
fi

# 9. Final success message
echo "========================================"
echo "Success!"
echo "Successfully downloaded and saved the requested images:"
if [[ "$PULL_SAVE_MAIN" == true ]]; then
  echo " - Main image: ${OUTPUT_FILENAME}"
fi
if [[ "$PULL_SAVE_TOOLS" == true ]]; then
  echo " - Tools image: ${OUTPUT_TOOLS_FILENAME}"
fi
echo "========================================"

exit 0
