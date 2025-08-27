#!/usr/bin/env bash
set -o nounset -o errexit -o xtrace

# Offline Package Archive Script
# This script packages the contents of compose/universal into compose/offline/package.tar.gz for closed network installation
# and downloads docker-compose binaries for both x86_64 and aarch64 architectures.

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
OFFLINE_DIR=$(realpath "$SCRIPT_DIR/offline")

function archive_package() {
  pushd "universal"
  [[ -f ${OFFLINE_DIR}/package.tar.gz ]] && rm -f "${OFFLINE_DIR}"/package.tar.gz
  tar zcvf "${OFFLINE_DIR}"/package.tar.gz .
  popd
}

function save_docker_compose() {
  local kernel=linux hardware
  for hardware in x86_64 aarch64; do
    curl -fsSL "https://dl.querypie.com/releases/bin/v2.39.1/docker-compose-${kernel}-${hardware}" -o offline/docker-compose-${kernel}-${hardware}
  done
}

function main() {
  pushd "$SCRIPT_DIR"

  archive_package
  save_docker_compose
}

main "$@"
