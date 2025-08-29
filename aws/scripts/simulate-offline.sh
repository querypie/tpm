#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail

BOLD_CYAN="\e[1;36m"
BOLD_YELLOW="\e[1;33m"
BOLD_RED="\e[1;91m"
RESET="\e[0m"

function log::do() {
  # shellcheck disable=SC2064
  trap "log::error 'Failed to run: $*'" ERR
  printf "%b+ %s%b\n" "$BOLD_CYAN" "$*" "$RESET" 1>&2
  "$@"
}

function log::warning() {
  printf "%bWARNING: %s%b\n" "$BOLD_YELLOW" "$*" "$RESET" 1>&2
}

function log::error() {
  printf "%bERROR: %s%b\n" "$BOLD_RED" "$*" "$RESET" 1>&2
}
echo "# Simulate offline environment by blocking network access to a few domains."

# 192.0.2.0/24 is reserved for documentation and examples (RFC 5737)
# You can replace it with any non-routable IP address if needed.
cat <<'EOF' | sudo tee /etc/hosts

# Block access to external container registries
192.0.2.1   dl.querypie.com
192.0.2.2   docker.io
192.0.2.3   hub.docker.com
EOF

if log::do curl -fsSL --connect-timeout 5 --max-time 5 https://dl.querypie.com/setup.v2.sh; then
  echo "ERROR: Network access to dl.querypie.com is still available."
  exit 1
else
  echo "Network access to dl.querypie.com is successfully blocked."
fi

if log::do curl -fsSL --connect-timeout 5 --max-time 5 -o /dev/null -w "%{http_code}\n" \
  https://hub.docker.com/v2/repositories/querypie/querypie/tags/; then
  echo "ERROR: Network access to docker.io is still available."
  exit 1
else
  echo "Network access to docker.io is successfully blocked."
fi
