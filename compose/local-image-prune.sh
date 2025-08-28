#!/usr/bin/env bash
set -o nounset -o errexit -o xtrace

if docker --version 2>/dev/null | grep -q "^Docker version"; then
  DOCKER=docker
elif podman --version 2>/dev/null | grep -q "^podman version"; then
  DOCKER=podman
else
  echo >&2 "# Unknown version of Docker"
  docker --version
  exit 1
fi

$DOCKER image prune --all --force || true
