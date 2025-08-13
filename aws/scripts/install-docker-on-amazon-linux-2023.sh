#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail
set -o xtrace

function install_docker_and_compose() {
  local hardware
  hardware=$(uname -m)

  sudo dnf install -y docker
  curl -SL https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-linux-"${hardware}" \
    -o /tmp/docker-compose
  if file /tmp/docker-compose | grep -q "ELF 64-bit LSB executable"; then
    if [[ -d /usr/libexec/docker/cli-plugins/ ]]; then
      sudo install -m 755 /tmp/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
    fi
    sudo install -m 755 /tmp/docker-compose /usr/local/bin/docker-compose
  fi

  sudo systemctl start docker
  sudo systemctl enable docker

  sudo usermod -aG docker "$USER"
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
    install_docker_and_compose
    shutdown_ssh_session
  fi
}

main "$@"
