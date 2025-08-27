#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail

BOLD_CYAN="\e[1;36m"
BOLD_RED="\e[1;91m"
RESET="\e[0m"

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

function packer::verify() {
  local ami_id=$1 packer_option="${PACKER_OPTION:-}"
  # NOTE(JK): Use `PACKER_OPTION=-on-error=abort` to allow debugging the AMI build process.
  echo >&2 "### Verify AMI with Packer ###"
  echo >&2 "PACKER_OPTION: $packer_option"

  # Disable SC2086(Use double quotes to prevent word splitting) to allow expansion of variables.
  # shellcheck disable=SC2086
  log::do packer build \
    -var "source_ami=$ami_id" \
    -timestamp-ui \
    ${packer_option} \
    ami-verify.pkr.hcl |
    sed 's/ ==> amazon-ebs\.ami-verify://'
    # Remove the builder name of '==> amazon-ebs.ami-verify:'
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
  local ami_id=${1:-} ami_name timestamp
  if [[ -z "$ami_id" ]]; then
    echo "Usage: $0 <ami_id>"
    exit 1
  fi

  validate_environment

  packer::verify "$ami_id"
}

main "$@"
