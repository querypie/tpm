#!/usr/bin/env bash
set -o nounset -o errexit -o errtrace -o pipefail
# Push Container Images to a Private Container Registry

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

function detect_docker_buildx_imagetools() {
  echo >&2 "## Detecting docker buildx imagetools"
  if log::do docker buildx imagetools | grep "docker buildx imagetools"; then
    echo >&2 "# Found: docker buildx imagetools"
    return
  fi
  log::error "Not found: docker buildx imagetools"
  log::error "Please install Docker Desktop to proceed."
  exit 1
}

function pull_and_push_container_images() {
  echo >&2 "## Pulling and Pushing Container Images to Private Registry"

  local compose_yml=$1 version=$2 private_registry=$3 compose_dir tmp_image_list
  compose_dir=$(dirname "$compose_yml")
  tmp_image_list=$(mktemp /tmp/images.XXXXXX)

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
    docker compose --profile database --profile app --profile tools config | grep 'image:' | awk '{print $2}' >"$tmp_image_list"
    docker compose --file novac-compose.yml --profile novac config | grep 'image:' | awk '{print $2}' >>"$tmp_image_list"
    rm -f .env
  )
  popd

  local image image_parts tag lastname renamed_image platform
  while read -r image; do
    [[ -n "$image" ]] || continue
    IFS=':/' read -ra image_parts <<< "$image"
    tag=${image_parts[-1]}
    lastname=${image_parts[-2]}
    renamed_image="${private_registry}${lastname}:${tag}"
    for platform in amd64 arm64; do
      log::do docker pull --quiet --platform linux/$platform "$image"
      log::do docker tag "$image" "$renamed_image-$platform"
      log::do docker push --quiet "$renamed_image-$platform"
    done
    log::do docker buildx imagetools create -t "$renamed_image" "$renamed_image-amd64" "$renamed_image-arm64"
  done <"$tmp_image_list"
  rm -f "$tmp_image_list"
}

function main() {
  local compose_yml=${1:-} version=${2:-} private_registry=${3:-}
  if [[ -z ${compose_yml} || -z ${version} || -z ${private_registry} ]]; then
    cat <<END_OF_USAGE
Usage: $0 <compose.yml> <version> <private_registry>
  compose.yml: Path to the docker-compose YAML file
  version: QueryPie version to save as .tar (e.g., 11.1.2)
  private_registry: Private container registry URL (e.g., registry.example.com/querypie-release/)

EXAMPLES:
  $0 universal/compose.yml 11.1.2 docker.io/your-username/
  $0 universal/compose.yml 11.1.2 docker.io/your-username/

END_OF_USAGE
    exit 1
  fi

  echo >&2 "### Push Container Images to a Private Container Registry ###"
  echo >&2 "# ${BASH:-}${ZSH_NAME:-} ${BASH_VERSION:-}${ZSH_VERSION:-}"
  echo >&2 "# QueryPie version specified: $version"

  if [[ "$private_registry" != */ ]]; then
    log::error "Trailing slash (/) is required for private_registry."
    exit 1
  fi

  log::do cd "$SCRIPT_DIR"
  log::do detect_docker_buildx_imagetools
  log::do pull_and_push_container_images "$compose_yml" "$version" "$private_registry"
}

main "$@"
