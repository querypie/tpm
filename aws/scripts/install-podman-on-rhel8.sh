#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail
set -o xtrace

packages=(
  podman
  podman-plugins
  podman-manpages
)

function install_podman() {
  sudo dnf -y -q --best install "${packages[@]}"

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
