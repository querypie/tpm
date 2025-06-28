#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail

BOLD_CYAN="\e[1;36m"
BOLD_RED="\e[1;91m"
RESET="\e[0m"

function log::do() {
  # print ascii color code for bold cyan and reset
  printf "%b+ %s%b\n" "$BOLD_CYAN" "$*" "$RESET" 1>&2
  if "$@"; then
    return 0
  else
    log::error "Failed to run: $*"
    return 1
  fi
}

function log::error() {
  printf "%bERROR: %s%b\n" "$BOLD_RED" "$*" "$RESET" 1>&2
}

function packer::build() {
  local version=$1 ami_name=$2 packer_option="${PACKER_OPTION:-}"
  # NOTE(JK): Use `PACKER_OPTION=-on-error=abort` to allow debugging the AMI build process.
  echo >&2 "### Build AMI with Packer ###"
  echo >&2 "PACKER_OPTION: $packer_option"

  # Disable SC2086(Use double quotes to prevent word splitting) to allow expansion of variables.
  # shellcheck disable=SC2086
  log::do packer build \
    -var "querypie_version=$version" \
    -var "ami_name=$ami_name" \
    -var "docker_auth=$DOCKER_AUTH" \
    -timestamp-ui \
    ${packer_option} \
    querypie-ami.pkr.hcl |
    sed 's/ ==> build-querypie-ami\.amazon-ebs\.amazon-linux-2023://'
    # Remove builder name of '==> build-querypie-ami.amazon-ebs.amazon-linux-2023:'
}

function aws::image_id() {
  local ami_name=$1
  echo >&2 "### Get AMI ID ###"
  log::do aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=$ami_name" \
    --query 'Images[0].ImageId' \
    --output text
}

function validate_environment() {
  if ! command -v packer &>/dev/null; then
    log::error "Packer is not installed. Please install Packer to continue."
    exit 1
  fi

  if ! command -v aws &>/dev/null; then
    log::error "AWS CLI is not installed. Please install AWS CLI to continue."
    exit 1
  fi

  if [[ -z "${DOCKER_AUTH:-}" ]]; then
    log::error "DOCKER_AUTH environment variable is not set. Please set it to the base64-encoded Docker registry authentication."
    exit 1
  fi
}

function main() {
  local querypie_version=${1:-} ami_name timestamp
  if [[ -z "$querypie_version" ]]; then
    echo "Usage: $0 <querypie_version>"
    echo "  MODE=release $0 <querypie_version>"
    exit 1
  fi

  validate_environment

  timestamp=$(date +%Y%m%d%H%M)
  if [[ "${MODE:-}" == "release" ]]; then
    ami_name="QueryPie-Suite-${querypie_version}"
  else
    ami_name="QueryPie-Suite-${querypie_version}-${timestamp}"
  fi

  packer::build "$querypie_version" "${ami_name}"

  local image_id
  image_id=$(aws::image_id "$ami_name")
}

main "$@"
