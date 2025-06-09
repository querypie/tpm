#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail

BOLD_CYAN="\e[1;36m"
BOLD_RED="\e[1;91m"
RESET="\e[0m"

function log::do() {
  # print ascii color code for bold cyan and reset
  printf "%b+ %s%b\n" "$BOLD_CYAN" "$*" "$RESET" 1>&2
  if "$@"; then
    return 0
  else
    log::error "Failed to run: $*"
    return 1
  fi
}

function log::error() {
  printf "%bERROR: %s%b\n" "$BOLD_RED" "$*" "$RESET" 1>&2
}

function random_hex() {
  local length=${1:-32}
  if command -v openssl >/dev/null; then
    openssl rand -hex $((length / 2))
    return 0
  fi
  if command -v xxd >/dev/null; then
    xxd -l "$((length / 2))" -p /dev/urandom
    return 0
  fi
  log::error "Cannot generate a random hex string."
  log::error "Please make sure that you have openssl(1) or xxd(1) installed in the host."
  exit 1
}

function read_user_input() {
  local prompt=$1 default=$2 value
  if [[ -t 0 ]]; then
    read -r -p "${prompt} [${default}]: " value
    echo "${value:-${default}}"
  else
    echo "${default}"
  fi
}

function determine_value() {
  local name=$1 existing_value=$2

  # Priority 1: Use the value from the environment if it exists.
  if [[ -n "${!name:-}" ]]; then
    echo "${!name}"
    return
  fi

  # Priority 2: Use the value from the source file if it exists.
  if [[ -n "${existing_value}" ]]; then
    echo "${existing_value}"
    return
  fi

  # Priority 3: Provide default values for specific variables.
  case "${name}" in
  AGENT_SECRET)
    random_hex 32
    ;;
  KEY_ENCRYPTION_KEY)
    random_hex 12
    ;;
  DB_PASSWORD | REDIS_PASSWORD)
    random_hex 8
    ;;
  DB_HOST)
    echo host.docker.internal
    ;;
  DB_USERNAME)
    echo querypie
    ;;
  REDIS_NODES)
    echo host.docker.internal:6379
    ;;
  *)
    log::error "Unexpected variable: ${name}"
    ;;
  esac
}

function generate_env() {
  local source_env=$1 line name value existing_value
  while IFS= read -r -u 9 line; do
    if [[ -z "${line}" || "${line}" =~ ^\s*# ]]; then
      # Skip empty lines and comments.
      echo "${line}"
      continue
    fi

    name=${line%%=*}
    existing_value=${line#*=}
    value=$(determine_value "${name}" "${existing_value}")
    echo "${name}=${value}"
  done 9<"${source_env}" # 9 is unused file descriptor to read ${source_env}.
}

function main() {
  if [[ $# -lt 0 ]]; then
    echo "Usage: $0 <compose-env>"
    exit 1
  fi
  local source_env=$1
  if [[ ! -r "${source_env}" ]]; then
    log::error "Cannot read the source environment file: ${source_env}"
    exit 1
  fi

  echo >&2 "## Generating a docker env file from ${source_env}..."
  generate_env "${source_env}"
}

main "$@"
