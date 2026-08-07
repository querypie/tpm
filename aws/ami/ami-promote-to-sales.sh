#!/usr/bin/env bash
# Promote a verified QPE AMI to a Sales-owned Marketplace source AMI.
#
# Usage:
#   ./ami-promote-to-sales.sh <qpe_ami_id>

# The AWS accounts, profiles, and Regions are intentionally fixed for the
# QueryPie Marketplace release workflow.

SCRIPT_VERSION="26.08.1"

[[ -n "${ZSH_VERSION:-}" ]] && emulate bash
set -o nounset -o errexit -o errtrace -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

readonly BOLD_CYAN="\e[1;36m"
readonly BOLD_YELLOW="\e[1;33m"
readonly BOLD_RED="\e[1;91m"
readonly RESET="\e[0m"

readonly QPE_ACCOUNT_ID="142605707876"
readonly SALES_ACCOUNT_ID="883790944456"
readonly QPE_PROFILE="qpe"
readonly SALES_PROFILE="sales"
readonly SOURCE_REGION="ap-northeast-2"
readonly DESTINATION_REGION="us-east-1"
readonly COPY_POLL_INTERVAL_SECONDS=15
readonly COPY_TIMEOUT_SECONDS=3600

SOURCE_AMI_ID=""
TARGET_AMI_ID=""
SOURCE_AMI_NAME=""
TARGET_AMI_NAME=""
SOURCE_ARCHITECTURE=""
SOURCE_VERSION=""
SOURCE_BUILD_DATE=""
SHARING_ATTEMPTED=false
COPY_IN_PROGRESS=false
COPY_AVAILABLE=false
COPY_TERMINAL=false
declare -a SOURCE_SNAPSHOT_IDS=()

export AWS_CLI_AUTO_PROMPT=off
export AWS_PAGER=""

function log::error() {
  printf "%bERROR: %s%b\n" "$BOLD_RED" "$*" "$RESET" 1>&2
}

function log::warning() {
  printf "%bWARNING: %s%b\n" "$BOLD_YELLOW" "$*" "$RESET" 1>&2
}

function log::info() {
  printf "%b%s%b\n" "$BOLD_CYAN" "$*" "$RESET" 1>&2
}

function log::do() {
  local line_no status
  line_no=$(caller | awk '{print $1}')
  printf "%b+ %s%b\n" "$BOLD_CYAN" "$*" "$RESET" 1>&2
  if "$@"; then
    return 0
  else
    status=$?
  fi

  log::error "Failed to run at line $line_no: $*"
  return "$status"
}

function print_usage_and_exit() {
  local code=${1:-0} out=2
  [[ $code -eq 0 ]] && out=1
  cat >&"${out}" <<END_OF_USAGE
Usage: $0 <qpe_ami_id>

Promote a verified QPE AMI to a Sales-owned, unencrypted Marketplace source
AMI in us-east-1. The source and destination accounts, profiles, and Regions
are built into this script and cannot be overridden.

FIXED SETTINGS:
  QPE account/profile/Region    ${QPE_ACCOUNT_ID} / ${QPE_PROFILE} / ${SOURCE_REGION}
  Sales account/profile/Region  ${SALES_ACCOUNT_ID} / ${SALES_PROFILE} / ${DESTINATION_REGION}

OPTIONS:
  -h, --help      Show this help message
  -V, --version   Show the script version
  -x, --xtrace    Enable Bash execution tracing

PREREQUISITE:
  The source AMI must already have passed ami-verify.sh.

END_OF_USAGE
  exit "$code"
}

function validate::environment() {
  if ! command -v aws >/dev/null 2>&1; then
    log::error "AWS CLI is not installed. Please install it to continue."
    exit 1
  fi
}

function validate::ami_id() {
  local ami_id=$1
  if [[ ! "$ami_id" =~ ^ami-[0-9a-f]{8}([0-9a-f]{9})?$ ]]; then
    log::error "AMI ID must use the format ami- followed by 8 or 17 lowercase hexadecimal characters."
    exit 1
  fi
}

function aws::qpe() {
  log::do aws --profile "$QPE_PROFILE" --region "$SOURCE_REGION" "$@"
}

function aws::sales() {
  log::do aws --profile "$SALES_PROFILE" --region "$DESTINATION_REGION" "$@"
}

function validate::account() {
  local profile=$1 expected_account_id=$2 actual_account_id
  actual_account_id=$(log::do aws --profile "$profile" sts get-caller-identity \
    --query Account \
    --output text)

  if [[ "$actual_account_id" != "$expected_account_id" ]]; then
    log::error "AWS profile '$profile' must use account $expected_account_id, but found $actual_account_id."
    exit 1
  fi
}

function validate::sales_encryption_default() {
  local encryption_by_default
  encryption_by_default=$(aws::sales ec2 get-ebs-encryption-by-default \
    --query EbsEncryptionByDefault \
    --output text)

  if [[ "$encryption_by_default" != "False" ]]; then
    log::error "EBS encryption by default must be disabled in Sales $DESTINATION_REGION."
    log::error "Current value: $encryption_by_default"
    exit 1
  fi
}

function source::validate() {
  log::do env \
    AWS_PROFILE="$QPE_PROFILE" \
    AMI_REGION="$SOURCE_REGION" \
    "$SCRIPT_DIR/ami-validate.sh" "$SOURCE_AMI_ID"
}

function source::load_metadata() {
  local max_source_name_length metadata snapshot_ids
  metadata=$(aws::qpe ec2 describe-images \
    --owners self \
    --image-ids "$SOURCE_AMI_ID" \
    --query 'Images[0].[Name,Architecture]' \
    --output text)
  IFS=$'\t' read -r SOURCE_AMI_NAME SOURCE_ARCHITECTURE <<<"$metadata"

  if [[ -z "$SOURCE_AMI_NAME" || "$SOURCE_AMI_NAME" == "None" ]]; then
    log::error "Could not determine the name of source AMI $SOURCE_AMI_ID."
    exit 1
  fi

  # Keep the Sales AMI name unique even when the same release version is rebuilt.
  max_source_name_length=$((128 - 1 - ${#SOURCE_AMI_ID}))
  TARGET_AMI_NAME="${SOURCE_AMI_NAME:0:max_source_name_length}-${SOURCE_AMI_ID}"

  SOURCE_VERSION=$(aws::qpe ec2 describe-images \
    --owners self \
    --image-ids "$SOURCE_AMI_ID" \
    --query "Images[0].Tags[?Key=='Version'].Value | [0]" \
    --output text)
  SOURCE_BUILD_DATE=$(aws::qpe ec2 describe-images \
    --owners self \
    --image-ids "$SOURCE_AMI_ID" \
    --query "Images[0].Tags[?Key=='BuildDate'].Value | [0]" \
    --output text)

  snapshot_ids=$(aws::qpe ec2 describe-images \
    --owners self \
    --image-ids "$SOURCE_AMI_ID" \
    --query 'Images[0].BlockDeviceMappings[?Ebs.SnapshotId!=`null`].Ebs.SnapshotId' \
    --output text)
  # AWS CLI text output separates multiple snapshot IDs with whitespace.
  read -r -a SOURCE_SNAPSHOT_IDS <<<"$snapshot_ids"

  if [[ ${#SOURCE_SNAPSHOT_IDS[@]} -eq 0 || "${SOURCE_SNAPSHOT_IDS[0]}" == "None" ]]; then
    log::error "AMI $SOURCE_AMI_ID does not have an EBS snapshot."
    exit 1
  fi
}

function permissions::contains_sales_account() {
  local permissions=$1
  [[ "$permissions" =~ (^|[[:space:]])${SALES_ACCOUNT_ID}($|[[:space:]]) ]]
}

function permissions::image_state() {
  local permissions
  if ! permissions=$(aws::qpe ec2 describe-image-attribute \
    --image-id "$SOURCE_AMI_ID" \
    --attribute launchPermission \
    --query 'LaunchPermissions[].UserId' \
    --output text); then
    log::error "Could not inspect launch permissions for AMI $SOURCE_AMI_ID."
    return 1
  fi

  if permissions::contains_sales_account "$permissions"; then
    echo "present"
  else
    echo "absent"
  fi
}

function permissions::snapshot_state() {
  local snapshot_id=$1 permissions
  if ! permissions=$(aws::qpe ec2 describe-snapshot-attribute \
    --snapshot-id "$snapshot_id" \
    --attribute createVolumePermission \
    --query 'CreateVolumePermissions[].UserId' \
    --output text); then
    log::error "Could not inspect create-volume permissions for snapshot $snapshot_id."
    return 1
  fi

  if permissions::contains_sales_account "$permissions"; then
    echo "present"
  else
    echo "absent"
  fi
}

function permissions::grant() {
  local image_state snapshot_id snapshot_state
  log::info "### Grant temporary Sales access to the QPE AMI ###"
  SHARING_ATTEMPTED=true

  if ! image_state=$(permissions::image_state); then
    return 1
  fi
  if [[ "$image_state" == "present" ]]; then
    log::info "AMI launch permission already includes Sales account $SALES_ACCOUNT_ID."
  else
    aws::qpe ec2 modify-image-attribute \
      --image-id "$SOURCE_AMI_ID" \
      --launch-permission "Add=[{UserId=${SALES_ACCOUNT_ID}}]"
  fi

  for snapshot_id in "${SOURCE_SNAPSHOT_IDS[@]}"; do
    if ! snapshot_state=$(permissions::snapshot_state "$snapshot_id"); then
      return 1
    fi
    if [[ "$snapshot_state" == "present" ]]; then
      log::info "Snapshot $snapshot_id already includes Sales account $SALES_ACCOUNT_ID."
    else
      aws::qpe ec2 modify-snapshot-attribute \
        --snapshot-id "$snapshot_id" \
        --attribute createVolumePermission \
        --operation-type add \
        --user-ids "$SALES_ACCOUNT_ID"
    fi
  done

  if ! image_state=$(permissions::image_state); then
    return 1
  fi
  if [[ "$image_state" != "present" ]]; then
    log::error "Sales launch permission was not applied to AMI $SOURCE_AMI_ID."
    return 1
  fi
  for snapshot_id in "${SOURCE_SNAPSHOT_IDS[@]}"; do
    if ! snapshot_state=$(permissions::snapshot_state "$snapshot_id"); then
      return 1
    fi
    if [[ "$snapshot_state" != "present" ]]; then
      log::error "Sales create-volume permission was not applied to snapshot $snapshot_id."
      return 1
    fi
  done
}

function permissions::revoke_image() {
  local image_state
  if ! image_state=$(permissions::image_state); then
    return 1
  fi
  if [[ "$image_state" == "present" ]]; then
    aws::qpe ec2 modify-image-attribute \
      --image-id "$SOURCE_AMI_ID" \
      --launch-permission "Remove=[{UserId=${SALES_ACCOUNT_ID}}]"
  fi
}

function permissions::revoke_snapshot() {
  local snapshot_id=$1 snapshot_state
  if ! snapshot_state=$(permissions::snapshot_state "$snapshot_id"); then
    return 1
  fi
  if [[ "$snapshot_state" == "present" ]]; then
    aws::qpe ec2 modify-snapshot-attribute \
      --snapshot-id "$snapshot_id" \
      --attribute createVolumePermission \
      --operation-type remove \
      --user-ids "$SALES_ACCOUNT_ID"
  fi
}

function permissions::revoke_all() {
  local image_state snapshot_id snapshot_state status=0
  log::info "### Revoke Sales access from the QPE AMI ###"

  permissions::revoke_image || status=$((status + 1))
  for snapshot_id in "${SOURCE_SNAPSHOT_IDS[@]}"; do
    permissions::revoke_snapshot "$snapshot_id" || status=$((status + 1))
  done

  if ! image_state=$(permissions::image_state); then
    status=$((status + 1))
  elif [[ "$image_state" == "present" ]]; then
    log::error "Sales launch permission remains on AMI $SOURCE_AMI_ID."
    status=$((status + 1))
  fi
  for snapshot_id in "${SOURCE_SNAPSHOT_IDS[@]}"; do
    if ! snapshot_state=$(permissions::snapshot_state "$snapshot_id"); then
      status=$((status + 1))
    elif [[ "$snapshot_state" == "present" ]]; then
      log::error "Sales create-volume permission remains on snapshot $snapshot_id."
      status=$((status + 1))
    fi
  done

  ((status == 0))
}

function target::find_existing() {
  local image_ids
  image_ids=$(aws::sales ec2 describe-images \
    --owners self \
    --filters \
      "Name=tag:SourceAMI,Values=$SOURCE_AMI_ID" \
      "Name=tag:SourceAccount,Values=$QPE_ACCOUNT_ID" \
      "Name=tag:SourceRegion,Values=$SOURCE_REGION" \
    --query 'Images[].ImageId' \
    --output text)

  if [[ -z "$image_ids" || "$image_ids" == "None" ]]; then
    return 0
  fi

  local -a matches=()
  read -r -a matches <<<"$image_ids"
  if [[ ${#matches[@]} -ne 1 ]]; then
    log::error "Found ${#matches[@]} Sales AMIs promoted from $SOURCE_AMI_ID; expected at most one."
    return 1
  fi
  TARGET_AMI_ID=${matches[0]}
}

function target::copy() {
  local client_token description image_tags snapshot_tags
  client_token="querypie-${SOURCE_AMI_ID}-${DESTINATION_REGION}"
  description="Marketplace copy of ${SOURCE_AMI_NAME} from ${QPE_ACCOUNT_ID}/${SOURCE_REGION}/${SOURCE_AMI_ID}"

  image_tags="ResourceType=image,Tags=[{Key=Name,Value=${TARGET_AMI_NAME}},{Key=SourceAMI,Value=${SOURCE_AMI_ID}},{Key=SourceAccount,Value=${QPE_ACCOUNT_ID}},{Key=SourceRegion,Value=${SOURCE_REGION}},{Key=Architecture,Value=${SOURCE_ARCHITECTURE}}"
  snapshot_tags="ResourceType=snapshot,Tags=[{Key=Name,Value=${TARGET_AMI_NAME}-snapshot},{Key=SourceAMI,Value=${SOURCE_AMI_ID}},{Key=SourceAccount,Value=${QPE_ACCOUNT_ID}},{Key=SourceRegion,Value=${SOURCE_REGION}},{Key=Architecture,Value=${SOURCE_ARCHITECTURE}}"
  if [[ -n "$SOURCE_VERSION" && "$SOURCE_VERSION" != "None" ]]; then
    image_tags+=",{Key=Version,Value=${SOURCE_VERSION}}"
    snapshot_tags+=",{Key=Version,Value=${SOURCE_VERSION}}"
  fi
  if [[ -n "$SOURCE_BUILD_DATE" && "$SOURCE_BUILD_DATE" != "None" ]]; then
    image_tags+=",{Key=BuildDate,Value=${SOURCE_BUILD_DATE}}"
    snapshot_tags+=",{Key=BuildDate,Value=${SOURCE_BUILD_DATE}}"
  fi
  image_tags+="]"
  snapshot_tags+="]"

  log::info "### Copy the shared AMI into the Sales account ###"
  TARGET_AMI_ID=$(aws::sales ec2 copy-image \
    --source-region "$SOURCE_REGION" \
    --source-image-id "$SOURCE_AMI_ID" \
    --name "$TARGET_AMI_NAME" \
    --description "$description" \
    --no-encrypted \
    --client-token "$client_token" \
    --tag-specifications "$image_tags" "$snapshot_tags" \
    --query ImageId \
    --output text)

  if [[ -z "$TARGET_AMI_ID" || "$TARGET_AMI_ID" == "None" ]]; then
    log::error "Sales copy request did not return an AMI ID."
    return 1
  fi
  COPY_IN_PROGRESS=true
}

function target::state() {
  aws::sales ec2 describe-images \
    --owners self \
    --image-ids "$TARGET_AMI_ID" \
    --query 'Images[0].State' \
    --output text
}

function target::wait_until_available() {
  local deadline state
  deadline=$((SECONDS + COPY_TIMEOUT_SECONDS))

  while ((SECONDS < deadline)); do
    state=$(target::state)
    case "$state" in
    available)
      COPY_IN_PROGRESS=false
      COPY_AVAILABLE=true
      return 0
      ;;
    pending)
      log::info "Sales AMI $TARGET_AMI_ID is pending. Waiting ${COPY_POLL_INTERVAL_SECONDS}s."
      log::do sleep "$COPY_POLL_INTERVAL_SECONDS"
      ;;
    failed | error | invalid)
      COPY_IN_PROGRESS=false
      COPY_TERMINAL=true
      log::error "Sales AMI $TARGET_AMI_ID entered terminal state '$state'."
      return 1
      ;;
    *)
      log::error "Sales AMI $TARGET_AMI_ID has unexpected state '$state'."
      return 1
      ;;
    esac
  done

  log::error "Timed out after ${COPY_TIMEOUT_SECONDS}s waiting for Sales AMI $TARGET_AMI_ID."
  return 1
}

function target::validate() {
  log::do env \
    AWS_PROFILE="$SALES_PROFILE" \
    AMI_REGION="$DESTINATION_REGION" \
    "$SCRIPT_DIR/ami-validate.sh" --marketplace-source "$TARGET_AMI_ID"
}

function cleanup::on_exit() {
  local status=$?
  trap - EXIT

  if [[ $status -ne 0 && -n "$SOURCE_AMI_ID" && ${#SOURCE_SNAPSHOT_IDS[@]} -gt 0 ]]; then
    if [[ "$COPY_AVAILABLE" == true || "$COPY_TERMINAL" == true ]]; then
      log::warning "The Sales copy is no longer in progress, so the source sharing permissions will be revoked."
      if ! permissions::revoke_all; then
        log::error "Some source sharing permissions could not be revoked. Re-run this command with $SOURCE_AMI_ID after resolving the AWS error."
      fi
    elif [[ "$COPY_IN_PROGRESS" == true ]]; then
      log::warning "The Sales copy may still be in progress. Source sharing permissions were left in place."
      log::warning "Re-run this command with $SOURCE_AMI_ID to resume validation and revoke sharing."
    elif [[ "$SHARING_ATTEMPTED" == true ]]; then
      log::warning "Promotion stopped before the Sales copy started. Revoking temporary Sales access."
      if ! permissions::revoke_all; then
        log::error "Some source sharing permissions could not be revoked. Re-run this command with $SOURCE_AMI_ID after resolving the AWS error."
      fi
    fi
  fi

  exit "$status"
}

function main() {
  local -a arguments=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      print_usage_and_exit 0
      ;;
    -V | --version)
      echo "$SCRIPT_VERSION"
      exit 0
      ;;
    -x | --xtrace)
      set -o xtrace
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      log::error "Unexpected option: $1"
      print_usage_and_exit 1
      ;;
    *)
      arguments+=("$1")
      shift
      ;;
    esac
  done

  if [[ ${#arguments[@]} -ne 1 ]]; then
    print_usage_and_exit 1
  fi
  SOURCE_AMI_ID=${arguments[0]}

  validate::ami_id "$SOURCE_AMI_ID"
  validate::environment
  trap cleanup::on_exit EXIT

  log::info "### Validate fixed AWS account contexts ###"
  validate::account "$QPE_PROFILE" "$QPE_ACCOUNT_ID"
  validate::account "$SALES_PROFILE" "$SALES_ACCOUNT_ID"
  validate::sales_encryption_default

  source::validate
  source::load_metadata
  target::find_existing

  if [[ -z "$TARGET_AMI_ID" ]]; then
    permissions::grant
    target::copy
  else
    log::info "Found existing Sales AMI $TARGET_AMI_ID promoted from $SOURCE_AMI_ID."
    local existing_state
    existing_state=$(target::state)
    case "$existing_state" in
    available)
      COPY_AVAILABLE=true
      ;;
    pending)
      COPY_IN_PROGRESS=true
      permissions::grant
      ;;
    failed | error | invalid)
      COPY_TERMINAL=true
      log::error "Existing Sales AMI $TARGET_AMI_ID is in terminal state '$existing_state'."
      return 1
      ;;
    *)
      log::error "Existing Sales AMI $TARGET_AMI_ID has unexpected state '$existing_state'."
      return 1
      ;;
    esac
  fi

  if [[ "$COPY_AVAILABLE" != true ]]; then
    target::wait_until_available
  fi
  target::validate
  permissions::revoke_all

  echo "Promoted AMI: $TARGET_AMI_ID"
  echo "Sales sharing revoked from QPE AMI: $SOURCE_AMI_ID"
}

main "$@"
