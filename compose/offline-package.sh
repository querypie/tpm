#!/usr/bin/env bash
set -o nounset -o errexit -o errtrace -o pipefail

# Offline Package Archive Script
# This script packages the contents of compose/universal into compose/offline/package.tar.gz for closed network installation
# and downloads docker-compose binaries for both x86_64 and aarch64 architectures.

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

# Color definitions
readonly BOLD_CYAN="\e[1;36m"
readonly BOLD_YELLOW="\e[1;33m"
readonly BOLD_RED="\e[1;91m"
readonly RESET="\e[0m"

# Logging functions
function log::do() {
  local line_no
  line_no=$(caller | awk '{print $1}')
  # shellcheck disable=SC2064
  trap "log::error 'Failed to run at line $line_no: $*'" ERR
  printf "%b+ %s%b\n" "$BOLD_CYAN" "$*" "$RESET" 1>&2
  "$@"
}

function log::warning() {
  printf "%bWARNING: %s%b\n" "$BOLD_YELLOW" "$*" "$RESET" 1>&2
}

function log::error() {
  printf "%bERROR: %s%b\n" "$BOLD_RED" "$*" "$RESET" 1>&2
}

function archive_package() {
  local compose_yml=$1 compose_dir
  echo >&2 "## Creating offline/package.tar.gz from $compose_yml"
  compose_dir=$(dirname "$compose_yml")
  pushd "$compose_dir"
  [[ -f $SCRIPT_DIR/offline/package.tar.gz ]] && log::do rm -f "$SCRIPT_DIR"/offline/package.tar.gz
  [[ -e .env ]] && log::do rm -f .env
  log::do tar zcvf "$SCRIPT_DIR"/offline/package.tar.gz .
  popd
}

function save_setup_script() {
  echo >&2 "## Saving setup.v2.sh script to offline/setup.v2.sh"
  log::do cp "$SCRIPT_DIR"/../aws/scripts/setup.v2.sh "$SCRIPT_DIR"/offline/setup.v2.sh
}

function save_docker_compose() {
  echo >&2 "## Downloading docker-compose binaries for x86_64 and aarch64"
  local kernel=linux hardware
  for hardware in x86_64 aarch64; do
    log::do curl -fsSL "https://dl.querypie.com/releases/bin/v2.39.1/docker-compose-${kernel}-${hardware}" -o offline/docker-compose-${kernel}-${hardware}
  done
}

function main() {
  local compose_yml=${1:-}
  if [[ -z ${compose_yml} ]]; then
    cat <<END_OF_USAGE
Usage: $0 <compose.yml>
  compose.yml: Path to the docker-compose YAML file

EXAMPLES:
  $0 universal/compose.yml
  $0 universal/compose.yml

END_OF_USAGE
    exit 1
  fi

  echo >&2 "### Offline Package Archiver ###"

  log::do cd "$SCRIPT_DIR"
  archive_package "$compose_yml"
  save_setup_script
  save_docker_compose
}

main "$@"
