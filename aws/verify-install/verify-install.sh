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
  local version=$1 distro=$2 architecture=$3 container_engine=$4
  local packer_option="${PACKER_OPTION:-}" packer
  # NOTE(JK): Use `PACKER_OPTION=-on-error=abort` to allow debugging the AMI build process.
  echo >&2 "### Install QueryPie and Verify with Packer ###"
  echo >&2 "PACKER_OPTION: $packer_option"

  packer=./${distro}.pkr.hcl
  if [[ ! -f ${packer} ]]; then
    log::error "No such distro available: $distro as ${packer}"
    exit 1
  fi

  # Disable SC2086(Use double quotes to prevent word splitting) to allow expansion of variables.
  # shellcheck disable=SC2086
  log::do packer build \
    -var "querypie_version=$version" \
    -var "architecture=${architecture}" \
    -var "container_engine=${container_engine}" \
    -var "resource_owner=${USER:-Unknown}" \
    -timestamp-ui \
    ${packer_option} \
    ${packer} |
    sed 's/ ==> amazon-ebs\.[a-zA-Z0-9_.-]*://'
  # Remove the builder name of '==> amazon-ebs.ubuntu24-04-install:'
}

function validate_environment() {
  if ! command -v packer &>/dev/null; then
    log::error "Packer is not installed. Please install Packer to continue."
    exit 1
  fi
}

function main() {
  local querypie_version=${1:-} distro=${2:-amazon-linux-2023} architecture=${3:-x86_64} container_engine=${4:-none}
  if [[ -z "$querypie_version" ]]; then
    cat <<END_OF_USAGE
Usage: $0 <querypie_version> [<distro>] [<architecture>] [<container_engine>]

EXAMPLE:
  $0 11.0.1 amazon-linux-2023
  $0 11.0.1 amazon-linux-2023 arm64
  $0 11.0.1 ubuntu-24.04
  $0 11.0.1 ubuntu-22.04
  $0 11.0.1 rhel8 x86_64 podman
  PACKER_OPTION=-on-error=abort $0 11.0.1 amazon-linux-2023

END_OF_USAGE
    exit 1
  fi

  validate_environment

  packer::build "$querypie_version" "$distro" "$architecture" "$container_engine"
}

main "$@"
