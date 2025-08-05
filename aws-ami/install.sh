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
  local distro=$1 version=$2 packer_option="${PACKER_OPTION:-}"
  # NOTE(JK): Use `PACKER_OPTION=-on-error=abort` to allow debugging the AMI build process.
  echo >&2 "### Install QueryPie and Verify with Packer ###"
  echo >&2 "PACKER_OPTION: $packer_option"

  if [[ ! -f $distro-install.pkr.hcl ]]; then
    log::error "No such distro available: $distro"
    exit 1
  fi

  # Disable SC2086(Use double quotes to prevent word splitting) to allow expansion of variables.
  # shellcheck disable=SC2086
  log::do packer build \
    -var "querypie_version=$version" \
    -timestamp-ui \
    ${packer_option} \
    $distro-install.pkr.hcl |
    sed 's/ ==> amazon-ebs\..*-install://'
  # Remove the builder name of '==> amazon-ebs.ubuntu24-04-install:'
}

function validate_environment() {
  if ! command -v packer &>/dev/null; then
    log::error "Packer is not installed. Please install Packer to continue."
    exit 1
  fi
}

function main() {
  local distro=${1:-} querypie_version=${2:-}
  if [[ -z "${distro}" || -z "$querypie_version" ]]; then
    cat <<END_OF_USAGE
Usage: $0 <distro> <querypie_version>

EXAMPLE:
  $0 az2023 11.0.1
  $0 ubuntu24.04 11.0.1
  $0 ubuntu22.04 11.0.1
  PACKER_OPTION=-on-error=abort $0 az2023 11.0.1

END_OF_USAGE
    exit 1
  fi

  validate_environment

  packer::install "$distro" "$querypie_version"
}

main "$@"
