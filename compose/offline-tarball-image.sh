#!/usr/bin/env bash
set -o nounset -o errexit -o errtrace -o pipefail

# Offline Tarball Image Archiver
# This script downloads container images and save them as tarballs.

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
DOCKER=docker

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

function detect_container_engine() {
  echo >&2 "## Detecting Docker or Podman"
  if log::do docker --version | grep "^Docker version"; then
    DOCKER=docker
    if $DOCKER ps >/dev/null 2>&1; then
      echo >&2 "# Docker is already running and functional."
      return
    fi
  elif log::do podman --version | grep "^podman version"; then
    DOCKER=podman
    if $DOCKER ps >/dev/null 2>&1; then
      echo >&2 "# Podman is already running and functional."
      return
    fi
  fi
  log::error "Neither Docker nor Podman is installed or functional. Please install one of them to proceed."
  exit 1
}

function save_container_images() {
  echo >&2 "## Saving container images to offline/images.txt and downloading them as .tar files"

  local compose_yml=$1 version=$2 platform=$3 compose_dir
  compose_dir=$(dirname "$compose_yml")

  pushd "$compose_dir"
  if [[ -f .env.template ]]; then
    log::do cp .env.template .env
  elif [[ -f compose-env ]]; then
    log::do cp compose-env .env
  elif [[ -f .env ]]; then
    echo >&2 "# Using existing .env file."
  else
    log::error "No .env.template or compose-env file found."
    exit 1
  fi
  (
    PATH=../../aws/scripts:$SCRIPT_DIR:$PATH

    set -o xtrace
    VERSION="$version" setup.v2.sh --populate-env .env
    $DOCKER compose --profile database --profile app --profile tools config | grep 'image:' | awk '{print $2}' >"$SCRIPT_DIR"/offline/images.txt
    $DOCKER compose --file novac-compose.yml --profile novac config | grep 'image:' | awk '{print $2}' >>"$SCRIPT_DIR"/offline/images.txt
    rm -f .env
  )
  popd

  pushd offline
  local image tarball hardware
  hardware=$(basename "$platform")
  while read -r image; do
    log::do $DOCKER pull --platform "$platform" "$image"
    tarball=$(echo "$image" | tr '/:' '__')-${hardware}.tar
    log::do $DOCKER save "$image" -o "${tarball}"
  done <images.txt
}

function main() {
  local compose_yml=${1:-} version=${2:-} platform=${3:-linux/amd64}
  if [[ -z ${compose_yml} || -z ${version} ]]; then
    cat <<END_OF_USAGE
Usage: $0 <compose.yml> <version> [platform]
  compose.yml: Path to the docker-compose YAML file
  version: QueryPie version to save as .tar (e.g., 11.1.2)
  platform: Target platform for the container images (e.g., linux/amd64 or linux/arm64)

EXAMPLES:
  $0 universal/compose.yml 11.1.2 linux/amd64
  $0 universal/compose.yml 11.1.2 linux/arm64

END_OF_USAGE
    exit 1
  fi

  echo >&2 "### Offline Tarball Image Archiver ###"
  echo >&2 "# QueryPie version specified: $version"

  log::do cd "$SCRIPT_DIR"
  detect_container_engine
  save_container_images "$compose_yml" "$version" "$platform"
}

main "$@"
