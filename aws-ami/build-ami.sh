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
  local version=$1
  echo >&2 "### Build AMI with Packer ###"
  log::do packer build \
    -var "querypie_version=$version" \
    -var "ami_name_prefix=$AMI_NAME_PREFIX" \
    querypie-ami.pkr.hcl
}

function aws::image_id() {
  local ami_name=$1 version=$2
  echo >&2 "### Get AMI ID ###"
  aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=$ami_name-$version" \
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
}

function main() {
  local build_version=${1:-}
  if [[ -z "$build_version" ]]; then
    echo "Usage: $0 <build_version>"
    exit 1
  fi

  validate_environment

  AMI_NAME_PREFIX="${AMI_NAME_PREFIX:-querypie-suite}"
  packer::build "$build_version" || true # ignore errors for debugging

  local image_id
  image_id=$(aws::image_id "$AMI_NAME_PREFIX" "$build_version")
}

main "$@"
