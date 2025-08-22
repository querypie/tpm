#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail
set -o xtrace

function install_docker() {
  sudo dnf install -y docker

  sudo systemctl start docker
  sudo systemctl enable docker

  sudo usermod -aG docker "$USER"
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

function test_if_docker_installed_already {
  # Show the current process list and group information
  ps ux
  id -Gn
  docker ps
}

function shutdown_ssh_session {
  killall sshd
}

function main() {
  if test_if_docker_installed_already; then
    :
  else
    install_docker
    install_docker_compose
    shutdown_ssh_session
  fi
}

main "$@"
