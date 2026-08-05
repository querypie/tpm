#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail

BOLD_CYAN="\e[1;36m"
BOLD_RED="\e[1;91m"
RESET="\e[0m"

function log::info() {
  printf "%b%s%b\n" "$BOLD_CYAN" "$*" "$RESET" 1>&2
}

function log::error() {
  printf "%bERROR: %s%b\n" "$BOLD_RED" "$*" "$RESET" 1>&2
}

function validate_environment() {
  if ! command -v aws &>/dev/null; then
    log::error "AWS CLI is not installed. Please install AWS CLI to continue."
    exit 1
  fi
}

function validate_value() {
  local label=$1 actual=$2 expected=$3
  if [[ "$actual" != "$expected" ]]; then
    log::error "$label must be '$expected', but found '$actual'."
    return 1
  fi
  printf "%-24s %s\n" "$label" "$actual"
}

function main() {
  local marketplace_source=false
  if [[ "${1:-}" == "--marketplace-source" ]]; then
    marketplace_source=true
    shift
  fi

  local ami_id=${1:-} region=${AMI_REGION:-ap-northeast-2}
  if [[ -z "$ami_id" ]]; then
    echo "Usage: $0 [--marketplace-source] <ami_id>"
    exit 1
  fi

  validate_environment

  local details state architecture root_device virtualization imds_support description
  details=$(aws ec2 describe-images \
    --region "$region" \
    --owners self \
    --image-ids "$ami_id" \
    --query 'Images[0].[State,Architecture,RootDeviceType,VirtualizationType,ImdsSupport,Description]' \
    --output text)

  if [[ -z "$details" || "$details" == "None" ]]; then
    log::error "AMI $ami_id was not found in the current AWS account in $region."
    exit 1
  fi

  IFS=$'\t' read -r state architecture root_device virtualization imds_support description <<<"$details"

  log::info "### Validate AMI attributes"
  local status=0
  printf "%-24s %s\n" "Region" "$region"
  if [[ "$marketplace_source" == true ]]; then
    validate_value "Marketplace region" "$region" "us-east-1" || status=$((status + 1))
  fi
  validate_value "State" "$state" "available" || status=$((status + 1))
  validate_value "Root device type" "$root_device" "ebs" || status=$((status + 1))
  validate_value "Virtualization type" "$virtualization" "hvm" || status=$((status + 1))
  validate_value "IMDS support" "$imds_support" "v2.0" || status=$((status + 1))

  case "$architecture" in
  x86_64 | arm64)
    printf "%-24s %s\n" "Architecture" "$architecture"
    ;;
  *)
    log::error "Architecture must be x86_64 or arm64, but found '$architecture'."
    status=$((status + 1))
    ;;
  esac

  if [[ -z "$description" || "$description" == "None" ]]; then
    log::error "AMI description must not be empty."
    status=$((status + 1))
  else
    printf "%-24s %s\n" "Description" "$description"
  fi

  local snapshot_ids snapshot_id encrypted
  # shellcheck disable=SC2016 # JMESPath uses a literal `null` expression.
  snapshot_ids=$(aws ec2 describe-images \
    --region "$region" \
    --owners self \
    --image-ids "$ami_id" \
    --query 'Images[0].BlockDeviceMappings[?Ebs.SnapshotId!=`null`].Ebs.SnapshotId' \
    --output text)

  if [[ -z "$snapshot_ids" || "$snapshot_ids" == "None" ]]; then
    log::error "AMI does not have an EBS snapshot."
    status=$((status + 1))
  else
    for snapshot_id in $snapshot_ids; do
      encrypted=$(aws ec2 describe-snapshots \
        --region "$region" \
        --snapshot-ids "$snapshot_id" \
        --query 'Snapshots[0].Encrypted' \
        --output text)
      validate_value "Snapshot $snapshot_id" "$encrypted" "False" || status=$((status + 1))
    done
  fi

  local total_ebs_size_gib
  # shellcheck disable=SC2016 # JMESPath uses a literal `null` expression.
  total_ebs_size_gib=$(aws ec2 describe-images \
    --region "$region" \
    --owners self \
    --image-ids "$ami_id" \
    --query 'sum(Images[0].BlockDeviceMappings[?Ebs.SnapshotId!=`null`].Ebs.VolumeSize)' \
    --output text)
  if [[ ! "$total_ebs_size_gib" =~ ^[0-9]+$ ]]; then
    log::error "Total EBS size could not be determined, found '$total_ebs_size_gib'."
    status=$((status + 1))
  elif ((total_ebs_size_gib > 5120)); then
    log::error "Total EBS size must not exceed 5120 GiB, but found $total_ebs_size_gib GiB."
    status=$((status + 1))
  else
    printf "%-24s %s GiB\n" "Total EBS size" "$total_ebs_size_gib"
  fi

  if ((status > 0)); then
    log::error "AMI $ami_id failed $status structural validation check(s)."
    exit 1
  fi

  if [[ "$marketplace_source" == true ]]; then
    log::info "AMI $ami_id satisfies the structural checks required before Marketplace scanning."
  else
    log::info "AMI $ami_id satisfies the structural checks required before promotion."
  fi
}

main "$@"
