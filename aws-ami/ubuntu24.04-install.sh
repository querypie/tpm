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

function packer::install() {
  local version=$1 packer_option="${PACKER_OPTION:-}"
  # NOTE(JK): Use `PACKER_OPTION=-on-error=abort` to allow debugging the AMI build process.
  echo >&2 "### Install QueryPie and Verify with Packer ###"
  echo >&2 "PACKER_OPTION: $packer_option"

  # Disable SC2086(Use double quotes to prevent word splitting) to allow expansion of variables.
  # shellcheck disable=SC2086
  log::do packer build \
    -var "querypie_version=$version" \
    -timestamp-ui \
    ${packer_option} \
    ubuntu24.04-install.pkr.hcl |
    sed 's/ ==> amazon-ebs\.ubuntu24-04-install://'
    # Remove the builder name of '==> amazon-ebs.ubuntu24-04-install:'
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
  local querypie_version=${1:-} ami_name timestamp
  if [[ -z "$querypie_version" ]]; then
    echo "Usage: $0 <querypie_version>"
    exit 1
  fi

  validate_environment

  packer::install "$querypie_version"
}

main "$@"
