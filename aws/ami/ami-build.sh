#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail

BOLD_CYAN="\e[1;36m"
BOLD_RED="\e[1;91m"
RESET="\e[0m"

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

function log::do() {
  local line_no
  line_no=$(caller | awk '{print $1}')
  # shellcheck disable=SC2064
  trap "log::error 'Failed to run at line $line_no: $*'" ERR
  printf "%b+ %s%b\n" "$BOLD_CYAN" "$*" "$RESET" 1>&2
  "$@"
}

function log::error() {
  printf "%bERROR: %s%b\n" "$BOLD_RED" "$*" "$RESET" 1>&2
}

function packer::build() {
  local version=$1 architecture=$2 ami_name=$3 region=$4 packer_option="${PACKER_OPTION:-}"
  # NOTE(JK): Use `PACKER_OPTION=-on-error=abort` to allow debugging the AMI build process.
  echo >&2 "### Build AMI with Packer ###"
  echo >&2 "PACKER_OPTION: $packer_option"

  # Disable SC2086(Use double quotes to prevent word splitting) to allow expansion of variables.
  # shellcheck disable=SC2086
  log::do packer build \
    -var "querypie_version=$version" \
    -var "architecture=${architecture}" \
    -var "region=${region}" \
    -var "resource_owner=${USER:-Unknown}" \
    -var "ami_name=$ami_name" \
    -timestamp-ui \
    ${packer_option} \
    ami-build.pkr.hcl |
    sed 's/ ==> amazon-ebs\.[a-zA-Z0-9_.-]*://'
    # Remove the builder name of '==> amazon-ebs.amazon-linux-2023:'
}

function aws::image_id() {
  local ami_name=$1 region=$2
  echo >&2 "### Get AMI ID ###"
  log::do aws ec2 describe-images \
    --region "$region" \
    --owners self \
    --filters "Name=name,Values=$ami_name" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text
}

function validate_environment() {
  local region=$1
  if ! command -v packer &>/dev/null; then
    log::error "Packer is not installed. Please install Packer to continue."
    exit 1
  fi

  if ! command -v aws &>/dev/null; then
    log::error "AWS CLI is not installed. Please install AWS CLI to continue."
    exit 1
  fi

  if ! command -v session-manager-plugin &>/dev/null; then
    log::error "AWS Session Manager plugin is not installed. Please install session-manager-plugin to continue."
    exit 1
  fi

  log::do aws sts get-caller-identity --output text >/dev/null

  local encryption_by_default
  encryption_by_default=$(aws ec2 get-ebs-encryption-by-default \
    --region "$region" \
    --query EbsEncryptionByDefault \
    --output text)
  if [[ "$encryption_by_default" != "False" ]]; then
    log::error "EBS encryption by default must be disabled in $region for Marketplace-bound AMIs."
    log::error "Current value: $encryption_by_default"
    exit 1
  fi
}

function main() {
  local querypie_version=${1:-} distro=${2:-amazon-linux-2023} architecture=${3:-x86_64}
  local region=${AMI_REGION:-ap-northeast-2}
  if [[ -z "$querypie_version" ]]; then
    cat <<END_OF_USAGE
Usage: $0 <querypie_version> [<distro>] [<architecture>]

EXAMPLE:
  $0 11.0.1 amazon-linux-2023
  $0 11.0.1 amazon-linux-2023 arm64
  PACKER_OPTION=-on-error=abort $0 11.0.1 amazon-linux-2023

END_OF_USAGE
    exit 1
  fi

  if [[ "$distro" != "amazon-linux-2023" ]]; then
    log::error "Only amazon-linux-2023 is supported, not $distro."
    exit 1
  fi

  case "$architecture" in
  x86_64 | arm64) ;;
  *)
    log::error "Architecture must be x86_64 or arm64, not $architecture."
    exit 1
    ;;
  esac

  validate_environment "$region"

  local timestamp ami_name
  timestamp=$(date +%Y%m%d%H%M)
  if [[ "${MODE:-}" == "release" ]]; then
    ami_name="QueryPie-Suite-${querypie_version}"
  else
    ami_name="QueryPie-Suite-${querypie_version}-${timestamp}"
  fi

  packer::build "$querypie_version" "$architecture" "${ami_name}" "$region"

  local image_id
  image_id=$(aws::image_id "$ami_name" "$region")
  if [[ -z "$image_id" || "$image_id" == "None" ]]; then
    log::error "The completed build did not produce an AMI named $ami_name in $region."
    exit 1
  fi

  AMI_REGION="$region" ./ami-validate.sh "$image_id"
  echo "Built AMI: $image_id"
}

main "$@"
