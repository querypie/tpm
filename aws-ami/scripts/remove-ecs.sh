#!/usr/bin/env bash
# This script is used to remove the ECS agent and its related Docker images from the system.
# Amazon Linux 2023 is optimized for running ECS workloads by default.

set -o nounset -o errexit -o errtrace -o pipefail
set -o xtrace

function disable_ecs_agent_service() {
  sudo systemctl stop ecs
  sudo systemctl disable ecs
}

function docker_system_prune() {
  docker stop ecs-agent
  docker rm ecs-agent
  docker system prune --force --all --volumes
}

function main() {
  disable_ecs_agent_service || true
  docker_system_prune || true
}

main "$@"
