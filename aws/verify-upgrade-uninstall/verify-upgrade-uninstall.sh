#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail

function print_usage_and_exit() {
  set +x
  local code=${1:-0} out=2
  [[ code -eq 0 ]] && out=1
  cat <<END_OF_USAGE
Usage: $0 <initial_version> <upgrade_version> [<distro>] [<architecture>] [<container_engine>]

  initial_version:  Initial version of QueryPie to install (e.g., 11.0.1)
  upgrade_version:  Upgrade version of QueryPie to upgrade to (e.g., 11.1.1)
  distro:           amazon-linux-2023, ubuntu-24.04, ubuntu-22.04
  architecture:     Target CPU architecture (default: x86_64)
                    Supported architectures: x86_64, arm64
  container_engine: Container engine to use (default: none)
                    Supported engines: none, docker, podman

EXAMPLE:
  $0 11.0.1 11.1.1 amazon-linux-2023
  $0 11.0.1 11.1.1 amazon-linux-2023 arm64
  $0 11.0.1 11.1.1 ubuntu-24.04
  $0 11.0.1 11.1.1 ubuntu-22.04
  $0 11.0.1 11.1.1 ubuntu-24.04 x86_64 podman
  PACKER_OPTION=-on-error=abort $0 11.0.1 11.1.1 amazon-linux-2023

OPTIONS:
  $0 -h | --help
      Show this help message and exit.
  $0 -x | --xtrace
      Enable bash xtrace mode for debugging.
  $0 -on-error=abort | --abort
      Packer option to abort on error.
  $0 -timestamp-ui | --timestamp-ui | --timestamp | -timestamp
      Packer option to show timestamps in the UI.

END_OF_USAGE
  exit "$code"
}

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

PACKER_OPTIONS=()
function packer::build() {
  local initial_version=$1 upgrade_version=$2
  shift 2
  local distro=$1 architecture=$2 container_engine=$3 packer
  echo >&2 "### Install, Upgrade, and Uninstall QueryPie with Packer ###"
  echo >&2 "PACKER_OPTIONS: ${PACKER_OPTIONS[*]}"

  packer=./${distro}.pkr.hcl
  if [[ ! -f ${packer} ]]; then
    log::error "No such distro available: $distro as ${packer}"
    exit 1
  fi

  # Disable SC2086(Use double quotes to prevent word splitting) to allow expansion of variables.
  # shellcheck disable=SC2086
  log::do packer build \
    -var "initial_version=$initial_version" \
    -var "upgrade_version=$upgrade_version" \
    -var "architecture=${architecture}" \
    -var "container_engine=${container_engine}" \
    -var "resource_owner=${USER:-Unknown}" \
    "${PACKER_OPTIONS[@]}" \
    ${packer} |
    tee log/packer-"${initial_version}"-"${upgrade_version}"-"${distro}"-"${architecture}"-"${container_engine}".log
}

function validate_environment() {
  if ! command -v packer &>/dev/null; then
    log::error "Packer is not installed. Please install Packer to continue."
    exit 1
  fi
}

function main() {
  local -a arguments=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -x | --xtrace)
      set -o xtrace
      shift
      ;;
    -h | --help)
      print_usage_and_exit 0
      ;;
    -on-error=*)
      PACKER_OPTIONS+=("$1")
      shift
      ;;
    --abort)
      PACKER_OPTIONS+=("-on-error=abort")
      shift
      ;;
    -timestamp-ui | --timestamp-ui | --timestamp | -timestamp)
      PACKER_OPTIONS+=(-timestamp-ui)
      shift
      ;;
    --) # End of all options
      shift
      break
      ;;
    -*)
    # Got unexpected arguments
      log::error "Unexpected option received: $1"
      print_usage_and_exit 1
      ;;
    *)
      arguments+=("$1")
      shift
      ;;
    esac
  done

  if [[ ${#arguments[@]} -gt 0 ]]; then
    set -- "${arguments[@]}"
  else
    set --
  fi

  local initial_version=${1:-} upgrade_version=${2:-}
  [[ -n "$initial_version" && -n "$upgrade_version" ]] || print_usage_and_exit 1

  shift 2
  local distro=${1:-amazon-linux-2023} architecture=${2:-x86_64} container_engine=${3:-none}
  validate_environment
  packer::build "$initial_version" "$upgrade_version" \
    "$distro" "$architecture" "$container_engine"
}

main "$@"
