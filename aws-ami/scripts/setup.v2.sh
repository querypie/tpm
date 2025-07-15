#!/usr/bin/env bash
# This script provides a quick and easy way to install QueryPie.
# Run the following commands:
# $ bash <(curl -s https://dl.querypie.com/setup.v2.sh)
# or
# $ curl -s https://dl.querypie.com/setup.v2.sh -o setup.v2.sh
# $ bash setup.v2.sh --install <version>
# $ bash setup.v2.sh --upgrade <version>

set -o nounset -o errexit -o errtrace -o pipefail

# Version will be manually increased by the author.
SCRIPT_VERSION="25.07.4"     # YY.MM.PATCH
RECOMMENDED_VERSION="11.0.0" # QueryPie version to install by default.
ASSUME_YES=false

function print_usage_and_exit() {
  set +x
  local status=${1:-0} out=2 program_name
  program_name="$(basename "${BASH_SOURCE[0]}")"
  [[ status -eq 0 ]] && out=1
  cat >&"${out}" <<END
setup.v2.sh ${SCRIPT_VERSION}, the QueryPie installation script.
Usage: $program_name [options]
    or $program_name [options] --install <version>
    or $program_name [options] --upgrade <version>
    or $program_name [options] --install-partially-for-ami <version>
    or $program_name [options] --resume
    or $program_name [options] --verify-installation
    or $program_name [options] --populate-env <compose-env-file>
    or $program_name [options] --reset-credential <compose-env-file>
    or $program_name [options] --help

OPTIONS:
  --yes               Assume "yes" to all prompts and run non-interactively.
  -V, --version       Show the version of this script.
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
  echo >&2 "## Configure sudo privileges"
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

function install::verify_docker_installation() {
  echo >&2 "#"
  echo >&2 "## Verify Docker installation"
  echo >&2 "#"

  if docker ps >/dev/null 2>&1; then
    echo >&2 "# Docker is already running and functional."
    return
  fi
  if (docker ps 2>&1 || true) | grep -q "permission denied"; then
    echo >&2 "# The current user does not have permission to run Docker commands."
    echo >&2 "# The current groups for the user are:"
    log::do id -Gn

    local user
    user="$(id -un 2>/dev/null || true)"
    if getent group docker | grep -qw "$user"; then
      log::do getent group docker
      echo >&2 "# User '$user' is already in the Docker group."
      echo >&2 "# Please log out and log back in to apply the group changes."
    else
      echo >&2 "# Adding user '$user' to the Docker group."
      log::sudo usermod -aG docker "$user"
      echo >&2 "# User '$user' has been added to the Docker group. A logout and login is required to use Docker without sudo."
    fi
    echo >&2 "# Please rerun this script after logging back in."
    exit 1
  fi

  log::do docker ps || true
  echo >&2 "# Docker installation verification failed. Please check above errors."
  echo >&2 "# Resolve the identified issues before proceeding."
  exit 1
}

function install::docker() {
  echo >&2 "#"
  echo >&2 "## Install Docker engine"
  echo >&2 "#"

  if command_exists docker; then
    echo >&2 "# Docker is already installed at $(command -v docker)"

    install::verify_docker_installation
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
  echo >&2 "# User '$user' has been added to the Docker group. A logout and login is required to use Docker without sudo."
  echo >&2 "# Please rerun this script after logging back in."
  exit 1 # It could not complete the installation. So, exit with error.
}

function install::docker_compose() {
  echo >&2 "#"
  echo >&2 "## Install Docker Compose tool"
  echo >&2 "#"

  if command_exists docker-compose; then
    echo >&2 "# Docker Compose is already installed at $(command -v docker-compose)"
    return
  fi

  echo >&2 "# Docker Compose is not installed. Installing now."
  log::do curl -fsSL "https://dl.querypie.com/releases/bin/docker-compose-$(uname -s)-$(uname -m)" -o docker-compose
  log::sudo install -m 755 docker-compose /usr/local/bin
  rm docker-compose
}

function install::config_files() {
  echo >&2 "#"
  echo >&2 "## Install configuration files: docker-compose.yml, compose-env, and others"
  echo >&2 "#"

  echo >&2 "# Target directory is ./querypie/${QP_VERSION}/"
  mkdir -p ./querypie/"${QP_VERSION}"

  log::do curl -fsSL https://dl.querypie.com/releases/compose/"$PACKAGE_VERSION"/package.tar.gz -o package.tar.gz
  log::do tar zxvf package.tar.gz -C ./querypie/"$QP_VERSION"
  rm package.tar.gz
  log::do sed -i.orig \
    -e "s#- \\./mysql:/var/lib/mysql#- ../mysql:/var/lib/mysql#" \
    -e "s#harbor.chequer.io/querypie/#docker.io/querypie/#" \
    -e "s#source: /var/log/querypie#source: ../log#" \
    ./querypie/"$QP_VERSION"/docker-compose.yml
  rm ./querypie/"$QP_VERSION"/docker-compose.yml.orig
  log::do sed -i.orig \
    -e "s#^VERSION=.*#VERSION=$QP_VERSION#" \
    -e "s#CABINET_DATA_DIR=/data#CABINET_DATA_DIR=../data#" \
    ./querypie/"$QP_VERSION"/compose-env
  rm ./querypie/"$QP_VERSION"/compose-env.orig

  # Deprecated since 10.3.0
  if grep -q CABINET_DATA_DIR ./querypie/"$QP_VERSION"/compose-env; then
    log::do mkdir -p ./querypie/data
  fi

  # ./querypie/mysql is used by default, instead of ./querypie/<version>/mysql.
  if [[ ! -d ./querypie/mysql ]]; then
    log::do mkdir -p ./querypie/mysql
  fi

  # ./querypie/log is used by default, instead of /var/log/querypie.
  if [[ ! -d ./querypie/log ]]; then
    log::do mkdir -p ./querypie/log
  fi

  # Create a symbolic link to the compose-env file,
  # so that user can skip --env-file option when running docker-compose commands.
  [[ -e ./querypie/"$QP_VERSION"/.env ]] ||
    log::do ln -s compose-env ./querypie/"$QP_VERSION"/.env

  log::sudo cp ./querypie/"$QP_VERSION"/logrotate /etc/logrotate.d/docker-querypie
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
  REDIS_CONNECTION_MODE) # Deprecated since 10.3.0
    echo STANDALONE
    ;;
  QUERYPIE_WEB_URL | AWS_ACCOUNT_ID) # Deprecated since 10.3.0
    echo ""                          # Empty string for these variables.
    ;;
  *)
    echo >&2 "# Extra variable: ${name}"
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
    # Please note that box lines are aligned with the date string.
    cat <<END_OF_SUCCESSFUL_BANNER
.--------------------------------------------------------.
|  🚀 QueryPie Tools has been successfully started! 🚀   |
|  Timestamp in UTC: $(TZ=UTC date)        |
|  Timestamp in KST: $(TZ=KST-9 date)        |
'--------------------------------------------------------'
END_OF_SUCCESSFUL_BANNER
  else
    # Please note that box lines are aligned with the date string.
    cat <<END_OF_FAILURE_BANNER
.--------------------------------------------------------.
|  ❌ QueryPie Tools has failed to start ! ❌            |
|  Timestamp in UTC: $(TZ=UTC date)        |
|  Timestamp in KST: $(TZ=KST-9 date)        |
'--------------------------------------------------------'
END_OF_FAILURE_BANNER
  fi
}

function upgrade::is_higher_version() {
  local current=$1 target=$2 higher
  higher=$(printf '%s\n%s' "$current" "$target" | sort -V | tail -n1)
  if [[ "$higher" == "$target" && "$target" != "$current" ]]; then
    return 0
  else
    return 1
  fi
}

function verify::version_of_current() {
  readlink querypie/current || {
    log::error "Unable to find the current version out in ./querypie."
    exit 1
  }
}

function verify::version_of_container() {
  local container=querypie-app-1
  docker inspect --format '{{.Config.Image}}' $container | cut -d':' -f2
}

function verify::container_is_ready_for_service() {
  echo >&2 "## Verify the QueryPie app container is running properly"

  local container=querypie-app-1
  if log::do docker inspect --format '{{.State.Running}}' $container 2>/dev/null | grep -q 'true'; then
    echo >&2 "# QueryPie app container, $container is running."
  else
    log::error "QueryPie app container, $container is not running. Please check the installation."
    return 1
  fi

  # Find out the version of the QueryPie app container.
  echo >&2 "# QueryPie version: $(verify::version_of_container || true)"

  if log::do docker exec querypie-app-1 readyz wait; then
    echo >&2 "# QueryPie app container, $container is ready for service."
  else
    log::error "QueryPie app container is not functioning properly. Please check the installation."
    return 1
  fi
}

################################################################################
# Commands

function install::get_package_version() {
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

function install::make_symlink_of_current() {
  echo >&2 "## Create a symbolic link 'current' pointing to ${QP_VERSION}"
  local current_version
  current_version=$(readlink ./querypie/current || true)
  if [[ "$current_version" == "$QP_VERSION" ]]; then
    echo >&2 "# ./querypie/current already exists and points to ${QP_VERSION}."
    echo >&2 "# No need to create a new symbolic link."
    return
  fi

  log::do pushd "./querypie/"
  log::do rm -f current
  log::do ln -s "${QP_VERSION}" current
  log::do popd
}

function install::ask_yes() {
  echo "$@" >&2
  if [[ $ASSUME_YES == true ]]; then
    echo 'Do you agree? [y/N] :' 'yes'
    return
  elif [[ ! -t 0 ]]; then
    echo >&2 "# Standard input is not a terminal. Unable to receive user input. Please use the following method instead:"
    echo >&2 "# bash <(curl -L https://dl.querypie.com/setup.v2.sh)"
    echo 'Do you agree? [y/N] :' 'no'
    return 1
  fi

  local answer
  read -r -p 'Do you agree? [y/N] : ' answer
  case "${answer}" in
  y | Y | yes | YES | Yes) return ;;
  *) return 1 ;;
  esac
}

function cmd::install() {
  local QP_VERSION=${1:-}

  echo >&2 "### Install QueryPie ###"
  echo >&2 "# QP_VERSION: ${QP_VERSION}"
  PACKAGE_VERSION=$(install::get_package_version "${PACKAGE_VERSION:-}" "${QP_VERSION}")
  echo >&2 "# PACKAGE_VERSION: ${PACKAGE_VERSION}"

  setup::sudo_privileges
  install::docker
  install::docker_compose
  install::config_files

  log::do pushd "./querypie/${QP_VERSION}/"
  echo >&2 "## Configure the compose-env file in ./querypie/${QP_VERSION}/"
  cmd::populate_env "compose-env"
  log::do docker-compose pull --quiet mysql redis tools app
  echo >&2 "## Start MySQL and Redis services for QueryPie"
  log::do docker-compose --profile database up --detach
  log::do sleep 10
  log::do docker-compose --profile tools up --detach
  log::do tools::wait_and_print_banner

  echo >&2 "## Run migrate.sh to initialize MySQL database for QueryPie"
  # Save the long output of migrate.sh as querypie-migrate.1.log
  log::do docker exec querypie-tools-1 /app/script/migrate.sh runall >~/querypie-migrate.1.log
  # Run migrate.sh again to ensure the migration is completed properly
  log::do docker exec querypie-tools-1 /app/script/migrate.sh runall | tee ~/querypie-migrate.log
  log::do docker-compose --profile tools down
  echo >&2 "## Start the QueryPie container (initialization takes about 2 minutes)"
  log::do docker-compose --profile querypie up --detach
  log::do docker exec querypie-app-1 readyz || {
    log::error "QueryPie container has failed to start up. Please check the logs."
    log::do docker logs --tail 100 querypie-app-1 || true
    exit 1
  }
  log::do popd

  install::make_symlink_of_current

  local ip_address
  ip_address="$(hostname -i)"
  echo >&2 "### Installation completed successfully"
  echo >&2 "### Access QueryPie at http://${ip_address}/ in your browser"
  echo >&2 "### Determine the public IP address of your host machine if needed"
}

function cmd::upgrade() {
  local QP_VERSION=${1:-} current_version container_version

  echo >&2 "### Upgrade QueryPie to ${QP_VERSION} ###"
  echo >&2 "# QP_VERSION: ${QP_VERSION}"
  PACKAGE_VERSION=$(install::get_package_version "${PACKAGE_VERSION:-}" "${QP_VERSION}")
  echo >&2 "# PACKAGE_VERSION: ${PACKAGE_VERSION}"

  verify::container_is_ready_for_service || {
    log::error "Upgrade is aborted."
    exit 1
  }
  current_version=$(verify::version_of_current)
  container_version=$(verify::version_of_container)
  if [[ ${current_version} != "${container_version}" ]]; then
    log::error "The current version of QueryPie in ./querypie/current/ is ${current_version}, but the container version is ${container_version}."
    log::error "Please make sure that you are running the correct version of QueryPie."
    exit 1
  fi

  if ! upgrade::is_higher_version "${current_version}" "${QP_VERSION}"; then
    echo >&2 "# The current version is already equal or higher than ${QP_VERSION}. No need to upgrade."
    return
  fi

  install::config_files

  echo >&2 "## Configure the compose-env file for target version at ./querypie/${QP_VERSION}/"
  log::do pushd "./querypie/${QP_VERSION}/"
  (
    if [[ -e ../current/compose-env ]]; then
      # shellcheck disable=SC1091
      source ../current/compose-env
    else
      log::error "No compose-env file found in ./querypie/current/."
      exit 1
    fi
    VERSION="${QP_VERSION}" # Set the VERSION variable to the target version.
    cmd::populate_env "compose-env"
  )

  echo >&2 "## Download Docker images for the target version"
  log::do docker-compose pull --quiet mysql redis tools app
  log::do popd

  echo >&2 "## Stop containers from the previous version"
  log::do pushd "./querypie/${current_version}/"
  log::do docker-compose --profile querypie down
  log::do docker-compose --profile tools down || true
  log::do popd

  echo >&2 "## Start the querypie-tools container for the target version"
  log::do pushd "./querypie/${QP_VERSION}/"
  log::do docker-compose --profile tools up --detach
  log::do tools::wait_and_print_banner

  echo >&2 "## Run migrate.sh to apply MySQL schema changes for QueryPie"
  # Save the long output of migrate.sh as querypie-migrate.1.log
  log::do docker exec querypie-tools-1 /app/script/migrate.sh runall >>~/querypie-migrate.1.log
  # Run migrate.sh again to ensure the migration is completed properly
  log::do docker exec querypie-tools-1 /app/script/migrate.sh runall | tee -a ~/querypie-migrate.log
  log::do docker-compose --profile tools down
  echo >&2 "## Start the QueryPie container (initialization takes about 2 minutes)"
  log::do docker-compose --profile querypie up --detach
  log::do docker exec querypie-app-1 readyz || {
    log::error "QueryPie container has failed to start up. Please check the logs."
    log::do docker logs --tail 100 querypie-app-1 || true
    exit 1
  }
  log::do popd

  container_version=$(verify::version_of_container)
  if [[ ${QP_VERSION} != "${container_version}" ]]; then
    log::error "The version of QueryPie container is ${container_version}, but the target version is ${QP_VERSION}."
    log::error "Please report this problem to the technical support team of QueryPie."
    exit 1
  fi

  install::make_symlink_of_current

  local ip_address
  ip_address="$(hostname -i)"
  echo >&2 "### Upgrade completed successfully"
  echo >&2 "### Access QueryPie at http://${ip_address}/ in your browser"
  echo >&2 "### Determine the public IP address of your host machine if needed"
}

function cmd::install_partially_for_ami() {
  local QP_VERSION=${1}

  echo >&2 "### Perform partial installation for AWS AMI Build ###"
  echo >&2 "# QP_VERSION: ${QP_VERSION}"
  PACKAGE_VERSION=$(install::get_package_version "${PACKAGE_VERSION:-}" "${QP_VERSION}")
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

  install::make_symlink_of_current

  echo >&2 "### Installation completed successfully"
}

function cmd::resume() {
  echo >&2 "### Resume the partially completed installation ###"

  local QP_VERSION
  verify::version_of_current >/dev/null # Check if the version can be determined.
  QP_VERSION=$(verify::version_of_current)
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

  install::make_symlink_of_current

  echo >&2 "### Installation completed successfully"
}

# Populate the environment variables in the source file.
function cmd::populate_env() {
  local source_env_file=$1 tmp_file

  tmp_file=$(mktemp /tmp/compose-env.XXXXXX)
  # SC2064 Use single quotes, otherwise this expands now rather than when signaled.
  #shellcheck disable=SC2064
  trap "rm -f ${tmp_file}" EXIT

  echo >&2 "# Generating Docker environment file from ${source_env_file} to ${tmp_file}"
  env_file::populate_env "${source_env_file}" >"${tmp_file}"
  echo >&2 "# Replacing original file ${source_env_file} with generated file ${tmp_file}"
  cp "${tmp_file}" "${source_env_file}"
}

# Reset the credential variables in the source file.
function cmd::reset_credential() {
  local source_env_file=$1 tmp_file

  tmp_file=$(mktemp /tmp/compose-env.XXXXXX)
  # SC2064 Use single quotes, otherwise this expands now rather than when signaled.
  #shellcheck disable=SC2064
  trap "rm -f ${tmp_file}" EXIT

  echo >&2 "# Resetting credentials in ${source_env_file} to ${tmp_file}"
  env_file::reset_credential_in_env "${source_env_file}" >"${tmp_file}"
  echo >&2 "# Replacing original file ${source_env_file} with reset file ${tmp_file}"
  cp "${tmp_file}" "${source_env_file}"
}

function cmd::verify_installation() {
  echo >&2 "#"
  echo >&2 "### Verify the installation"
  echo >&2 "#"
  local status=0 try=0

  if [[ -f /etc/systemd/system/querypie-first-boot.service ]]; then
    echo >&2 "## Check the querypie-first-boot systemd service"
    for try in {1..30}; do
      if [[ -e /var/lib/querypie/first-boot-done ]]; then
        echo >&2 "# QueryPie first boot is done."
        break
      fi
      echo >&2 "# Currently waiting for QueryPie first boot to complete (attempt ${try}/30)"
      log::do systemctl status querypie-first-boot || true
      sleep 10
    done

    if [[ ! -e /var/lib/querypie/first-boot-done ]]; then
      echo >&2 "# QueryPie first boot has not completed. There may be an issue with the first boot service."
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

  verify::container_is_ready_for_service || {
    log::do docker logs --tail 100 querypie-app-1 || true
    ((status += 1))
  }

  if [[ status -gt 0 ]]; then
    echo >&2 "# Installation verification failed with ${status} error(s). Please check the logs for details."
    echo >&2 "# Resolve the identified issues before proceeding."
    exit "${status}"
  else
    echo >&2 "# Installation verification completed successfully."
  fi
}

function cmd::install_recommended() {
  echo >&2 "### Install QueryPie version $RECOMMENDED_VERSION ###"
  if [[ -d ./querypie ]]; then
    if [[ -L ./querypie/current ]]; then
      local current_version
      current_version=$(readlink ./querypie/current || true)
      echo >&2 "# QueryPie version $current_version is already installed at ./querypie/${current_version}/"
      if [[ "${current_version}" == "${RECOMMENDED_VERSION}" ]]; then
        echo >&2 "# The recommended version is already installed."
        echo >&2 "# No need to install QueryPie (${RECOMMENDED_VERSION}) again."
        return
      else
        install::ask_yes "Do you want to upgrade QueryPie from ${current_version} to ${RECOMMENDED_VERSION}?"
        cmd::upgrade "${RECOMMENDED_VERSION}"
      fi
    else
      log::error "./querypie/current is not a symbolic link."
      echo >&2 "# ./querypie/current should be a symbolic link to the current version directory."
      echo >&2 "# The target installation directory ./querypie/ appears to be in an invalid state."
      log::do ls -al ./querypie || true
      log::do docker ps --all || true
      echo >&2 "# Please report this problem to the technical support team of QueryPie."
      exit 1
    fi
  else
    echo >&2 "# Directory ./querypie/ does not exist. QueryPie has not been installed on this system."
    install::ask_yes "Do you want to install QueryPie (${RECOMMENDED_VERSION})?"
    cmd::install "${RECOMMENDED_VERSION}"
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
    echo >&2 "# Version must be in the format 'major.minor.patch' (e.g., '10.2.5')."
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
  local cmd="install_recommended"
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --yes)
      ASSUME_YES=true
      shift
      ;;
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
    --version | -V)
      echo "setup.v2.sh: ${SCRIPT_VERSION}"
      exit 0
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
  install_recommended)
    cmd::install_recommended
    ;;
  install)
    require::version "$@"
    cmd::install "$@"
    ;;
  upgrade)
    require::version "$@"
    cmd::upgrade "$@"
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
