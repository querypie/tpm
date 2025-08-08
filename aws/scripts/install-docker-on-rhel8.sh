#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail
set -o xtrace

packages=(
  docker-ce
  docker-ce-cli             # version_gte 18.09
  containerd.io             # version_gte 18.09
  docker-compose-plugin     # version_gte 20.10
  docker-ce-rootless-extras # version_gte 20.10
  docker-buildx-plugin      # version_gte 23.0
  docker-model-plugin       # version_gte 28.2
)

function install_docker_and_compose() {
  local hardware
  hardware=$(uname -m)

  sudo dnf -y -q --setopt=install_weak_deps=False install dnf-plugins-core
  sudo rm -f /etc/yum.repos.d/docker-ce.repo /etc/yum.repos.d/docker-ce-staging.repo
  sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
  sudo dnf makecache

  sudo dnf -y -q --best install "${packages[@]}"

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
  pkill -f sshd
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
