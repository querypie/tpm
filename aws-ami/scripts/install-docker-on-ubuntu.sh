#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail
set -o xtrace

DOWNLOAD_URL=https://download.docker.com/linux

packages=(
  docker-ce
  docker-ce-cli # version_gte 18.09
  containerd.io # version_gte 18.09
  docker-compose-plugin # version_gte 20.10
  docker-ce-rootless-extras # version_gte 20.10
  docker-buildx-plugin # version_gte 23.0
  docker-model-plugin # version_gte 28.2
)

function install_docker() {
  local lsb_dist distro_version

  DEBIAN_FRONTEND=noninteractive sudo -E sudo apt -qq update

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.asc
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo install -m 0644 /tmp/docker.asc /etc/apt/keyrings/docker.asc

  lsb_dist="$(. /etc/os-release && echo "$ID" | tr '[:upper:]' '[:lower:]')"
  distro_version=$(lsb_release --codename | cut -f2)

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $DOWNLOAD_URL/$lsb_dist $distro_version stable" |
    sudo tee /etc/apt/sources.list.d/docker.list
  DEBIAN_FRONTEND=noninteractive sudo -E sudo apt -qq update

  DEBIAN_FRONTEND=noninteractive sudo -E apt-get -y -qq install "${packages[@]}"

  sudo systemctl start docker
  sudo systemctl enable docker

  sudo usermod -aG docker "$USER"
}

function main() {
  install_docker
}

main "$@"
