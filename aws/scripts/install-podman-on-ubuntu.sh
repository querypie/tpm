#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail
set -o xtrace

packages=(
  podman
  # podman-docker will not be installed intentionally, to verify that setup.v2.sh works well without it.
  # However, when setup.v2.sh installs Podman by itself, podman-docker will be installed for compatible user experience with Docker.
)

function install_podman() {
  sudo DEBIAN_FRONTEND=noninteractive apt -qq update
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq install "${packages[@]}"

  # Enable the Podman socket for docker-compose to interact with Podman
  systemctl --user enable --now podman.socket
}

function install_docker_compose() {
  local hardware
  hardware=$(uname -m)
  curl -SL https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-linux-"${hardware}" \
    -o /tmp/docker-compose
  if file /tmp/docker-compose | grep -q "ELF 64-bit LSB executable"; then
    install -m 755 -D /tmp/docker-compose ~/.docker/cli-plugins/docker-compose
    sudo install -m 755 /tmp/docker-compose /usr/local/bin/docker-compose
  fi
}

function test_if_podman_installed_already {
  # Show the current process list and group information
  ps ux
  id -Gn
  podman ps
}

function main() {
  if test_if_podman_installed_already; then
    :
  else
    install_podman
    install_docker_compose
  fi
}

main "$@"
