#!/bin/bash

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
  local version=$1 project_name=$2
  echo >&2 "### Build AMI with Packer ###"
  log::do packer build \
  -var "version=$version" \
  -var "project_name=$project_name" \
  ami-build.json
}

function aws::image_id() {
  local project_name=$1 version=$2
  echo >&2 "### Get AMI ID ###"
  aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=$project_name-$version" \
    --query 'Images[0].ImageId' \
    --output text
}

function main() {
  local build_version=${1:-}
  local project_name=${2:-"querypie-marketplace"}
  if [[ -z "$build_version" ]]; then
    echo "Usage: $0 <build_version> [<project_name>]"
    exit 1
  fi

  packer::build "$build_version" "$project_name" || true # ignore errors for debugging

  local image_id
  image_id=$(aws::image_id "$project_name" "$build_version")
}

main "$@"
