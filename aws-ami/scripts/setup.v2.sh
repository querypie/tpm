#!/usr/bin/env bash
# This script is for quick and easy installation by followings:
# $ curl -L https://dl.querypie.com/releases/compose/setup.v2.sh -o setup.v2.sh
# $ bash setup.v2.sh 10.2.5

set -o nounset -o errexit -o errtrace -o pipefail

function print_usage_and_exit() {
  set +x
  local status=${1:-0} out=2 program_name
  program_name="$(basename "${BASH_SOURCE[0]}")"
  [[ status -eq 0 ]] && out=1
  cat >&"${out}" <<END
Usage: $program_name [options] <version>
    or $program_name [options] --install <version>
    or $program_name [options] --upgrade <version>
    or $program_name [options] --install-partially-for-ami <version>
    or $program_name [options] --resume
    or $program_name [options] --verify-installation
    or $program_name [options] --populate-env <compose-env-file>
    or $program_name [options] --reset-credential <compose-env-file>
    or $program_name [options] --help

OPTIONS:
  -x, --xtrace        Print commands and their arguments as they are executed.
  -h, --help          Show this help message.

END
  exit "${status}"
}

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

declare -a SUDO=(sudo)
function log::sudo() {
  if [[ "${#SUDO[@]}" -eq 0 ]]; then
    log::do "$@"
  else
    log::do "${SUDO[@]}" "$@"
  fi
}

# /etc/os-release is provided by Linux Standard Base.
# https://refspecs.linuxfoundation.org/lsb.shtml
function lsb::id_like() {
  if [[ -r /etc/os-release ]]; then
    ( # Run in subshell, not to import variables into the current shell.
      . /etc/os-release
      echo "$ID_LIKE" | tr '[:upper:]' '[:lower:]'
    )
  else
    echo ""
  fi
}

function lsb::id() {
  # Every system that we officially support has /etc/os-release
  if [[ -r /etc/os-release ]]; then
    ( # Run in subshell, not to import variables into the current shell.
      . /etc/os-release
      echo "$ID" | tr '[:upper:]' '[:lower:]'
    )
  else
    # Returning an empty string here should be alright since the
    # case statements don't act unless you provide an actual value
    echo ""
  fi
}

function command_exists() {
  command -v "$@" >/dev/null 2>&1
}

function setup::sudo_privileges() {
  echo >&2 "#"
  echo >&2 "## Setup sudo privileges"
  echo >&2 "#"

  local user
  user="$(id -un 2>/dev/null || true)"
  if [[ "${user}" == 'root' ]]; then
    echo >&2 "# The current user is 'root'. No need to use sudo."
    SUDO=() # No need to use sudo.
  elif command_exists sudo; then
    echo >&2 "# 'sudo' will be used for privileged commands."
    SUDO=(sudo)
  else
    log::error "This installer needs the ability to run commands as root."
    log::error "We are unable to find 'sudo' available to make this happen."
    exit 1
  fi
}

function install::docker() {
  echo >&2 "#"
  echo >&2 "## Install docker"
  echo >&2 "#"

  if command_exists docker; then
    echo >&2 "# Skip installing docker, as it is found at $(command -v docker) "
    return
  fi

  local lsb_id lsb_id_like user
  lsb_id="$(lsb::id)"
  lsb_id_like="$(lsb::id_like)"
  user="$(id -un 2>/dev/null || true)"

  case "$lsb_id" in
  amzn)
    case "$lsb_id_like" in
    fedora)
      log::sudo dnf install -y docker
      ;;
    *)
      log::sudo amazon-linux-extras install -y docker
      ;;
    esac
    ;;
  rocky)
    log::sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
    log::sudo dnf install -y docker-ce
    ;;
  *)
    log::do curl -fsSL https://get.docker.com -o docker-install.sh
    log::sudo sh docker-install.sh
    ;;
  esac

  log::sudo systemctl enable --now docker
  log::sudo usermod -aG docker "$user"
  echo >&2 "# $user has been added to the docker group. Please log out and log back in to use the docker command."
}

function install::docker_compose() {
  echo >&2 "#"
  echo >&2 "## Install docker-compose"
  echo >&2 "#"

  if command_exists docker-compose; then
    echo >&2 "# Skip installing docker-compose, as it is found at $(command -v docker-compose)."
    return
  fi

  echo >&2 "# Install docker-compose, as it does not exist."
  log::do curl -fsSL "https://dl.querypie.com/releases/bin/docker-compose-$(uname -s)-$(uname -m)" -o docker-compose
  log::sudo install -m 755 docker-compose /usr/local/bin
  rm docker-compose
}

function install::config_files() {
  echo >&2 "#"
  echo >&2 "## Install config files: docker-compose.yml, compose-env, and more"
  echo >&2 "#"

  echo >&2 "# Target dir is ./querypie/${QP_VERSION}/"
  mkdir -p ./querypie/"${QP_VERSION}"

  log::do curl -fsSL https://dl.querypie.com/releases/compose/"$PACKAGE_VERSION"/package.tar.gz -o package.tar.gz
  log::do tar zxvf package.tar.gz -C ./querypie/"$QP_VERSION"
  rm package.tar.gz
  log::do sed -i.orig s/^VERSION=.*/VERSION="$QP_VERSION"/ ./querypie/"$QP_VERSION"/compose-env
  rm ./querypie/"$QP_VERSION"/compose-env.orig

  # Create a symbolic link to the compose-env file,
  # so that user can skip --env-file option when running docker-compose commands.
  [[ -e ./querypie/"$QP_VERSION"/.env ]] ||
    log::do ln -s compose-env ./querypie/"$QP_VERSION"/.env

  log::sudo cp ./querypie/"$QP_VERSION"/logrotate /etc/logrotate.d/querypie

  if [[ ! -d /var/log/querypie ]]; then
    log::sudo mkdir -p /var/log/querypie
  fi
}

################################################################################
# compose-env related functions

function env_file::random_hex() {
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

function env_file::determine_value() {
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
    env_file::random_hex 32
    ;;
  KEY_ENCRYPTION_KEY)
    env_file::random_hex 12
    ;;
  DB_PASSWORD | REDIS_PASSWORD)
    env_file::random_hex 8
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

function env_file::populate_env() {
  local source_env=$1 line name value existing_value

  while IFS= read -r -u 9 line; do
    if [[ -z "${line}" || "${line}" =~ ^\s*# ]]; then
      # Skip empty lines and comments.
      echo "${line}"
      continue
    fi

    name=${line%%=*}
    existing_value=${line#*=}
    value=$(env_file::determine_value "${name}" "${existing_value}")
    echo "${name}=${value}"
  done 9<"${source_env}" # 9 is unused file descriptor to read ${source_env}.
}

function env_file::reset_credential() {
  local name=$1 existing_value=$2

  case "${name}" in
  AGENT_SECRET)
    echo ""
    ;;
  KEY_ENCRYPTION_KEY)
    echo ""
    ;;
  DB_PASSWORD | REDIS_PASSWORD)
    echo ""
    ;;
  *)
    # For other variables, we do not reset them.
    echo "${existing_value}"
    ;;
  esac
}

function env_file::reset_credential_in_env() {
  local source_env=$1 line name value existing_value

  while IFS= read -r -u 9 line; do
    if [[ -z "${line}" || "${line}" =~ ^\s*# ]]; then
      # Skip empty lines and comments.
      echo "${line}"
      continue
    fi

    name=${line%%=*}
    existing_value=${line#*=}
    value=$(env_file::reset_credential "${name}" "${existing_value}")
    echo "${name}=${value}"
  done 9<"${source_env}" # 9 is unused file descriptor to read ${source_env}.
}

function tools::get_readyz() {
  curl --silent --output /dev/null --write-out "%{http_code}" \
    http://localhost:8050/health || true
}

function tools::wait_until_readyz_gets_ready() {
  local started_at ended_at repeated=0 i
  started_at=$(date +%s)

  # If readyz returns 200 for 3 times in a row, we consider it's ready.
  # It waits for 5 minutes at most, and fails if readyz does not get ready.
  for i in {1..300}; do
    if [[ "$(tools::get_readyz)" == "200" ]]; then
      repeated=$((repeated + 1))
      if ((repeated >= 3)); then
        return 0
      fi
    else
      repeated=0
    fi
    sleep 1
  done
  ended_at=$(date +%s)
  local elapsed=$((ended_at - started_at))
  echo >&2 "readyz will not be ready. Elapsed time: ${elapsed} seconds."
  return 1
}

function tools::wait_and_print_banner() {
  # TODO(JK): tools-readyz will be available in tools container in the future, later than 11.0.
  if tools::wait_until_readyz_gets_ready; then
    # Please note that box lines are aligned with date string.
    cat <<END_OF_SUCCESSFUL_BANNER
.--------------------------------------------------------.
|  🚀 QueryPie Tools has been successfully started! 🚀   |
|  Timestamp in UTC: $(TZ=UTC date)        |
|  Timestamp in KST: $(TZ=KST-9 date)        |
'--------------------------------------------------------'
END_OF_SUCCESSFUL_BANNER
  else
    # Please note that box lines are aligned with date string.
    cat <<END_OF_FAILURE_BANNER
.--------------------------------------------------------.
|  ❌ QueryPie Tools has failed to start ! ❌            |
|  Timestamp in UTC: $(TZ=UTC date)        |
|  Timestamp in KST: $(TZ=KST-9 date)        |
'--------------------------------------------------------'
END_OF_FAILURE_BANNER
  fi
}

function verify::get_version_of_querypie() {
  local container=querypie-app-1
  docker inspect --format '{{.Config.Image}}' $container | cut -d':' -f2
}

################################################################################
# Commands

function package_version() {
  local package_version=$1 image_version=$2
  if [[ -n "$package_version" ]]; then
    # If package_version is provided, return it directly.
    echo "$package_version"
  # Typically, the image version is in the format of 'major.minor.patch'.
  elif [[ "$image_version" =~ ^([0-9]+)\.([0-9]+)\. ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.x"
  else
    # If the version does not match the expected format, try replacing ending number with '.x'.
    echo "${image_version%.*}.x"
  fi
}

function cmd::install_partially_for_ami() {
  local QP_VERSION=${1}

  echo >&2 "### Install partially for AWS AMI Build. ###"
  echo >&2 "# QP_VERSION: ${QP_VERSION}"
  PACKAGE_VERSION=$(package_version "${PACKAGE_VERSION:-}" "${QP_VERSION}")
  echo >&2 "# PACKAGE_VERSION: ${PACKAGE_VERSION}"

  setup::sudo_privileges
  install::docker
  install::docker_compose
  install::config_files

  log::do pushd "./querypie/${QP_VERSION}/"
  cmd::populate_env "compose-env"
  log::do docker-compose pull --quiet mysql redis tools app
  log::do docker image ls
  cmd::reset_credential "compose-env"
  log::do popd

  echo >&2 "### Completed installation successfully."
}

function resume::find_out_version() {
  local latest_version
  latest_version=$(
    find querypie -maxdepth 1 -type d -regextype posix-egrep -regex '.*/[0-9]+\.[0-9]+\.[0-9]+' |
      sed 's:.*/::' |
      sort -V | # Sort by version number
      tail -n 1
  )
  if [[ -z "$latest_version" ]]; then
    log::error "Unable to find a target directory in ./querypie."
    exit 1
  fi
  echo "$latest_version"
}

function cmd::resume() {
  echo >&2 "### Resume a partially completed installation ###"

  local QP_VERSION
  resume::find_out_version >/dev/null # Check if the version can be determined.
  QP_VERSION=$(resume::find_out_version)
  echo >&2 "# QP_VERSION: ${QP_VERSION}"

  log::do pushd "./querypie/${QP_VERSION}/"
  cmd::populate_env "compose-env"
  log::do docker-compose --profile database up --detach
  log::do sleep 10
  log::do docker-compose --profile tools up --detach
  log::do tools::wait_and_print_banner

  # Save the long output of migrate.sh as querypie-migrate.1.log
  log::do docker exec querypie-tools-1 /app/script/migrate.sh runall >~/querypie-migrate.1.log
  # Run migrate.sh again to ensure the migration is completed properly
  log::do docker exec querypie-tools-1 /app/script/migrate.sh runall | tee ~/querypie-migrate.log
  log::do docker-compose --profile tools down
  log::do docker-compose --profile querypie up --detach
  log::do docker container ls --all
  log::do popd

  echo >&2 "### Completed installation successfully."
}

# Populate the environment variables in the source file.
function cmd::populate_env() {
  local source_env_file=$1 tmp_file

  tmp_file=$(mktemp /tmp/compose-env.XXXXXX)
  # SC2064 Use single quotes, otherwise this expands now rather than when signaled.
  #shellcheck disable=SC2064
  trap "rm -f ${tmp_file}" EXIT

  echo >&2 "## Generating a docker env file from ${source_env_file} as ${tmp_file}..."
  env_file::populate_env "${source_env_file}" >"${tmp_file}"
  echo >&2 "## Replacing the original file ${source_env_file} with the generated file ${tmp_file}..."
  cp "${tmp_file}" "${source_env_file}"
}

# Reset the credential variables in the source file.
function cmd::reset_credential() {
  local source_env_file=$1 tmp_file

  tmp_file=$(mktemp /tmp/compose-env.XXXXXX)
  # SC2064 Use single quotes, otherwise this expands now rather than when signaled.
  #shellcheck disable=SC2064
  trap "rm -f ${tmp_file}" EXIT

  echo >&2 "## Resetting credentials in ${source_env_file}..."
  env_file::reset_credential_in_env "${source_env_file}" >"${tmp_file}"
  echo >&2 "## Replacing the original file ${source_env_file} with the reset file ${tmp_file}..."
  cp "${tmp_file}" "${source_env_file}"
}

function cmd::verify_installation() {
  echo >&2 "#"
  echo >&2 "### Verify installation"
  echo >&2 "#"
  local status=0 try=0

  if [[ -f /etc/systemd/system/querypie-first-boot.service ]]; then
    echo >&2 "## querypie-first-boot systemd service is installed."
    for try in {1..30}; do
      if [[ -e /var/lib/querypie/first-boot-done ]]; then
        echo >&2 "# QueryPie first boot is done."
        break
      fi
      echo >&2 "# Waiting for QueryPie first boot to complete... (try ${try})"
      log::do systemctl status querypie-first-boot || true
      sleep 10
    done

    if [[ ! -e /var/lib/querypie/first-boot-done ]]; then
      echo >&2 "# QueryPie first boot is not done yet. There might be an issue with the first boot service."
      ((status += 1))
    fi

    log::do systemctl is-active --quiet querypie-first-boot || {
      log::error "QueryPie first boot service is not running. Please start the service."
      ((status += 1))
    }

    log::do systemctl status querypie-first-boot || {
      log::error "QueryPie first boot service status could not be retrieved."
      log::do journalctl -u querypie-first-boot || true
      ((status += 1))
    }
  fi

  log::do docker inspect querypie-app-1 >/dev/null 2>&1 || {
    log::error "QueryPie app container is not running. Please check the installation."
    log::do docker logs --tail 100 querypie-app-1 || true
    ((status += 1))
  }

  # Find out the version of the QueryPie app container.
  echo >&2 "# QueryPie version: $(verify::get_version_of_querypie || true)"

  log::do docker exec querypie-app-1 readyz || {
    log::error "QueryPie app verification failed. Please check the installation."
    log::do docker logs --tail 100 querypie-app-1 || true
    ((status += 1))
  }

  if [[ status -gt 0 ]]; then
    echo >&2 "# Installation verification failed with ${status} errors."
    echo >&2 "# Please check the logs and fix the issues."
    exit "${status}"
  else
    echo >&2 "# Installation verification completed successfully."
  fi
}

################################################################################
# Input validations

function require::version() {
  local version=${1:-}

  if [[ -z "${version}" ]]; then
    log::error "Version is required. Please provide a version."
    print_usage_and_exit 1
  fi

  if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log::error "Invalid version format: ${version}"
    echo >&2 "# Version should be in the format of 'major.minor.patch' such as '10.2.5'."
    print_usage_and_exit 1
  fi
}

function require::compose_env_file() {
  local filename=${1:-}

  if [[ -z "${filename}" ]]; then
    log::error "Source environment file is not specified."
    exit 1
  fi

  if [[ ! -f "${filename}" ]]; then
    log::error "Source environment file is not a normal file: ${filename}"
    exit 1
  fi

  if [[ ! -r "${filename}" || ! -f "${filename}" ]]; then
    log::error "Cannot read the source environment file: ${filename}"
    exit 1
  fi
}

function main() {

  local -a argv=()
  local cmd="install"
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -x | --xtrace)
      set -o xtrace
      shift
      ;;
    -h | --help)
      print_usage_and_exit 0
      ;;
    --install | --upgrade)
      cmd="${1#--}"
      shift
      ;;
    --install-partially-for-ami | --resume)
      cmd="${1#--}"
      shift
      ;;
    --verify-installation)
      cmd="${1#--}"
      shift
      ;;
    --populate-env | --reset-credential)
      cmd="${1#--}"
      shift
      ;;
    -*)
      # Got unexpected arguments
      log::error "Unexpected option received: $1"
      print_usage_and_exit 1
      ;;
    *)
      argv+=("$1")
      shift
      ;;
    esac
  done
  set -- "${argv[@]}"

  case "$cmd" in
  install)
    require::version "$@"
    echo >&2 "# Install is not implemented yet."
    ;;
  upgrade)
    require::version "$@"
    echo >&2 "# Upgrade is not implemented yet."
    exit 1
    ;;
  install-partially-for-ami)
    require::version "$@"
    cmd::install_partially_for_ami "$@"
    ;;
  resume)
    cmd::resume
    ;;
  verify-installation)
    cmd::verify_installation
    ;;
  populate-env)
    require::compose_env_file "$@"
    cmd::populate_env "$@"
    ;;
  reset-credential)
    require::compose_env_file "$@"
    cmd::reset_credential "$@"
    ;;
  *)
    log::error "Invalid action: $cmd"
    print_usage_and_exit 1
    ;;
  esac
}

main "$@"
