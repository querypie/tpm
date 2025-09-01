#!/usr/bin/env bash
# This script provides a quick and easy way to install QueryPie.
# Run the following commands:
# $ bash <(curl -s https://dl.querypie.com/setup.v2.sh)
# or
# $ curl -s https://dl.querypie.com/setup.v2.sh -o setup.v2.sh
# $ bash setup.v2.sh --install <version>
# $ bash setup.v2.sh --upgrade <version>

# The version will be manually increased by the author.
SCRIPT_VERSION="25.08.8" # YY.MM.PATCH
echo -n "#### setup.v2.sh - QueryPie Installer ${SCRIPT_VERSION}, " >&2
echo -n "${BASH:-}${ZSH_NAME:-} ${BASH_VERSION:-}${ZSH_VERSION:-}" >&2
echo >&2 " on $(uname -s) $(uname -m) ####"

# Ensure zsh compatibility
[[ -n "${ZSH_VERSION:-}" ]] && emulate bash
set -o nounset -o errexit -o pipefail

RECOMMENDED_VERSION="11.1.1" # QueryPie version to install by default.
ASSUME_YES=false
DOCKER=docker          # The default Container Engine
COMPOSE=docker-compose # The default Compose tool

function print_usage_and_exit() {
  set +x
  local code=${1:-0} out=2 program_name=setup.v2.sh
  [[ code -eq 0 ]] && out=1
  cat >&"${out}" <<END
$program_name ${SCRIPT_VERSION}, the QueryPie installation script.
Usage: $program_name [options]
    or $program_name [options] --install <version>
    or $program_name [options] --install-container-engine
    or $program_name [options] --install-compose-package <version>
    or $program_name [options] --upgrade <version>
    or $program_name [options] --uninstall
    or $program_name [options] --help

FOR AWS AMI BUILD MAINTAINER:
    or $program_name [options] --install-partially-for-ami <version>
    or $program_name [options] --resume
    or $program_name [options] --verify-installation
    or $program_name [options] --verify-not-installed
    or $program_name [options] --populate-env <env-file>
    or $program_name [options] --reset-credential <env-file>

ENVIRONMENT VARIABLES:

  DOCKER_REGISTRY                Default: 'docker.io/querypie/'
    The Docker registry to pull images from.
    You may specify a private registry such as 'myregistry.example.com/querypie/'.
    Note that the trailing slash is required, if you set this variable.
    Actual image names will be like 'myregistry.example.com/querypie/querypie:11.1.1'.

OPTIONS:
  --yes               Assume "yes" to all prompts and run non-interactively.
  -V, --version       Show the version of this script.
  -x, --xtrace        Print commands and their arguments as they are executed.
  -h, --help          Show this help message.

END
  exit "${code}"
}

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
function lsb::echo() {
  local var=$1

  # Every system that we officially support has /etc/os-release
  if [[ -r /etc/os-release ]]; then
    ( # Run in subshell, not to import variables into the current shell.
      . /etc/os-release
      echo "${!var}" | tr '[:upper:]' '[:lower:]'
    )
  else
    # Returning an empty string here should be alright,
    # since the case statements don't act unless you provide an actual value
    echo ""
  fi
}

function command::whereis() {
  # Use a subshell to avoid modifying the PATH in the current shell.
  (
    PATH=~/.docker/cli-plugins:/usr/libexec/docker/cli-plugins:$PATH command -v "$@" 2>/dev/null
  )
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
  elif command::whereis sudo >/dev/null; then
    echo >&2 "# 'sudo' will be used for privileged commands."
    SUDO=(sudo)
  else
    log::error "This installer needs the ability to run commands as root."
    log::error "We are unable to find 'sudo' available to make this happen."
    exit 1
  fi
}

function verify::container_engine_installation() {
  echo >&2 "#"
  echo >&2 "## Verify Container Engine installation"
  echo >&2 "#"

  if docker --version 2>/dev/null | grep -q "^Docker version"; then
    DOCKER=docker
    if $DOCKER ps >/dev/null 2>&1; then
      echo >&2 "# Docker is already running and functional."
      return
    fi
  elif podman --version 2>/dev/null | grep -q "^podman version"; then
    DOCKER=podman
    if $DOCKER ps >/dev/null 2>&1; then
      echo >&2 "# Podman is already running and functional."
      if systemctl --user is-active podman.socket; then
        echo >&2 "# Podman socket is active."
        return
      else
        echo >&2 "# Podman socket is not active. Enabling and starting podman.socket."
        log::do systemctl --user enable --now podman.socket
        if systemctl --user is-active podman.socket; then
          echo >&2 "# Podman socket is now active."
          return
        else
          log::error "Failed to activate Podman socket. Please check the Podman installation."
          exit 1
        fi
      fi
    fi
  else
    echo >&2 "# Unknown version of Docker or Podman"
    log::do docker --version || true
    log::do podman --version || true
    log::error "Please report this problem to the technical support team of QueryPie."
    exit 1
  fi

  if (${DOCKER} ps 2>&1 || true) | grep -q "permission denied"; then
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

  log::do $DOCKER ps || true
  echo >&2 "# Container Engine installation verification failed. Please check above errors."
  echo >&2 "# Resolve the identified issues before proceeding."
  exit 1
}

function install::docker_or_podman() {
  echo >&2 "#"
  echo >&2 "## Install Docker engine"
  echo >&2 "#"

  if command::whereis docker >/dev/null; then
    echo >&2 "# Docker is already installed at $(command::whereis docker)"

    verify::container_engine_installation
    log::do $DOCKER --version
    return
  elif command::whereis podman >/dev/null; then
    echo >&2 "# Podman is already installed at $(command::whereis podman)"

    verify::container_engine_installation
    log::do $DOCKER --version
    return
  fi

  local lsb_id lsb_id_like lsb_version_id user
  lsb_id="$(lsb::echo ID)"
  lsb_id_like="$(lsb::echo ID_LIKE)"
  lsb_version_id="$(lsb::echo VERSION_ID)"
  echo >&2 "# Detected Linux distribution: ID=$lsb_id, ID_LIKE=$lsb_id_like, VERSION_ID=$lsb_version_id"
  user="$(id -un 2>/dev/null || true)"

  case "$lsb_id" in
  amzn)
    case "$lsb_id_like" in
    fedora) # Amazon Linux 2023 - Docker is available, but Podman is not.
      log::sudo dnf install -y docker
      DOCKER=docker
      ;;
    *)
      log::sudo amazon-linux-extras install -y docker
      DOCKER=docker
      ;;
    esac
    ;;
  rhel)
    case "$lsb_id_like" in
    fedora) # Red Hat Enterprise Linux 8, Red Hat Enterprise Linux 9
      log::sudo dnf -y -q --best install podman podman-plugins podman-manpages podman-docker
      DOCKER=podman
      ;;
    *)
      log::sudo dnf -y -q --best install podman podman-plugins podman-manpages podman-docker
      DOCKER=podman
      ;;
    esac
    ;;
  rocky)
    # ID_LIKE="rhel centos fedora" - Rocky Linux 8
    log::sudo dnf -y -q --best install podman podman-plugins podman-manpages podman-docker
    DOCKER=podman
    ;;
  centos)
    # ID_LIKE=rhel fedora - CentOS Stream 9
    log::sudo dnf -y -q --best install podman podman-plugins podman-manpages podman-docker
    DOCKER=podman
    ;;
  ubuntu)
    case "$lsb_version_id" in
    24.04)
      log::sudo DEBIAN_FRONTEND=noninteractive apt -qq update
      log::sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq install podman podman-docker
      DOCKER=podman
      ;;
    22.04)
      # Podman version is 3.4.4 that is too outdated in Ubuntu 22.04 LTS
      # Install Docker instead of Podman on Ubuntu 22.04 LTS
      log::do curl -fsSL https://get.docker.com -o docker-install.sh
      log::sudo sh docker-install.sh
      DOCKER=docker
      ;;
    *)
      log::do curl -fsSL https://get.docker.com -o docker-install.sh
      log::sudo sh docker-install.sh
      DOCKER=docker
      ;;
    esac
    ;;
  *)
    log::do curl -fsSL https://get.docker.com -o docker-install.sh
    log::sudo sh docker-install.sh
    DOCKER=docker
    ;;
  esac

  if [[ $DOCKER == "podman" ]]; then
    # Enable the Podman socket for docker-compose to interact with Podman
    log::do systemctl --user enable --now podman.socket
    echo >&2 "# Podman is successfully installed at $(command::whereis podman)"
    return
  elif [[ $DOCKER == "docker" ]]; then
    log::sudo systemctl enable --now docker
    log::sudo usermod -aG docker "$user"
    echo >&2 "# Docker is successfully installed at $(command::whereis docker)"
    echo >&2 "# User '$user' has been added to the Docker group. A logout and login is required to use Docker without sudo."
    echo >&2 "# Please rerun this script after logging back in."
    return 7 # It could not complete the installation. So, exit with error.
  else
    log::error "Unknown Container Engine: $DOCKER"
    log::error "Please report this problem to the technical support team of QueryPie."
    exit 1
  fi
}

function install::docker_compose() {
  echo >&2 "#"
  echo >&2 "## Install Docker Compose tool"
  echo >&2 "#"

  if $DOCKER compose version &>/dev/null; then
    if $DOCKER compose version 2>/dev/null | grep -q "Docker Compose"; then
      COMPOSE=docker-compose
    elif $DOCKER compose version 2>/dev/null | grep -q "podman-compose"; then
      COMPOSE=podman-compose
    else
      COMPOSE="(Unknown)"
    fi
    echo >&2 "# Compose Tool, $COMPOSE is already installed at $(command::whereis $COMPOSE || echo '(Unknown)')"
    echo >&2 "# Compose Tool is enabled as a plugin for $DOCKER"
    log::do $DOCKER compose version
    return
  fi

  local kernel hardware
  kernel=$(uname -s | tr '[:upper:]' '[:lower:]')
  hardware=$(uname -m | tr '[:upper:]' '[:lower:]')
  [[ $hardware == arm64 ]] && hardware=aarch64
  if [[ $kernel == linux || $kernel == darwin ]] && [[ $hardware == x86_64 || $hardware == aarch64 ]]; then
    echo >&2 "# Docker Compose is not installed. Installing now."

    if [[ -r "${OFFLINE_DIR}/docker-compose-${kernel}-${hardware}" ]]; then
      echo >&2 "# Detected an ${OFFLINE_DIR}/docker-compose-${kernel}-${hardware} file."
      echo >&2 "# This file will be used instead of downloading a new one."
      echo >&2 "# Such behavior is intended for closed or air-gapped environments."
      log::do cp "${OFFLINE_DIR}/docker-compose-${kernel}-${hardware}" docker-compose
    else
      log::do curl -fsSL "https://dl.querypie.com/releases/bin/v2.39.1/docker-compose-${kernel}-${hardware}" -o docker-compose
    fi
    log::do install -m 755 -D docker-compose ~/.docker/cli-plugins/docker-compose
    log::sudo install -m 755 docker-compose /usr/local/bin
    log::do rm docker-compose
  fi

  if $DOCKER compose version &>/dev/null; then
    echo >&2 "# Now Docker Compose is installed at $(command::whereis docker-compose || echo '(Unknown)')"
    echo >&2 "# Docker Compose is enabled as a plugin for $DOCKER"
    log::do $DOCKER compose version
    return
  else
    echo >&2 "# Failed to install Docker Compose properly: $($DOCKER compose version 2>&1 || true)"
    log::error "Please report this problem to the technical support team of QueryPie."
    log::do uname -a
    log::do ${DOCKER} --version
    exit 1
  fi
}

function install::config_files() {
  echo >&2 "#"
  echo >&2 "## Install configuration files: docker-compose.yml, .env, and others"
  echo >&2 "#"

  echo >&2 "# Target directory is ./querypie/${QP_VERSION}/"
  mkdir -p ./querypie/"${QP_VERSION}"

  if [[ -r ${OFFLINE_DIR}/package.tar.gz ]]; then
    echo >&2 "# Detected an ${OFFLINE_DIR}/package.tar.gz file."
    echo >&2 "# This file will be used instead of downloading a new one."
    echo >&2 "# Such behavior is intended for closed or air-gapped environments."
    log::do cp "${OFFLINE_DIR}"/package.tar.gz package.tar.gz
  else
    log::do curl -fsSL https://dl.querypie.com/releases/compose/"$PACKAGE_VERSION"/package.tar.gz -o package.tar.gz
  fi
  log::do umask 0022 # Use 644 for files and 755 for directories by default
  log::do tar zxvf package.tar.gz -C ./querypie/"$QP_VERSION"
  log::do rm package.tar.gz

  local compose_yml=compose.yml
  [[ -f ./querypie/"$QP_VERSION"/${compose_yml} ]] || compose_yml=docker-compose.yml
  log::do sed -i.orig \
    -e "s#- \\./mysql:/var/lib/mysql#- ../mysql:/var/lib/mysql#" \
    -e "s#harbor.chequer.io/querypie/#${DOCKER_REGISTRY}#" \
    -e "s#docker.io/querypie/#${DOCKER_REGISTRY}#" \
    -e "s#source: /var/log/querypie#source: ../log#" \
    ./querypie/"$QP_VERSION"/${compose_yml}
  rm ./querypie/"$QP_VERSION"/${compose_yml}.orig

  if [[ -L ./querypie/"$QP_VERSION"/.env ]]; then
    sudo rm -f ./querypie/"$QP_VERSION"/.env
  fi
  if [[ -f ./querypie/"$QP_VERSION"/.env ]]; then
    echo >&2 "# ./querypie/${QP_VERSION}/.env already exists."
    echo >&2 "# No need to create a new .env file."
  elif [[ -f ./querypie/"$QP_VERSION"/.env.template ]]; then
    # Universal package.tar.gz has .env.template.
    log::do cp ./querypie/"$QP_VERSION"/.env.template ./querypie/"$QP_VERSION"/.env
  elif [[ -f ./querypie/"$QP_VERSION"/compose-env ]]; then
    log::do cp ./querypie/"$QP_VERSION"/compose-env ./querypie/"$QP_VERSION"/.env
    # Use .env instead of compose-env,
    # so that user can skip the --env-file option when running docker-compose commands.
  fi
  log::do sed -i.orig \
    -e "s#^VERSION=.*#VERSION=$QP_VERSION#" \
    -e "s#CABINET_DATA_DIR=/data#CABINET_DATA_DIR=../data#" \
    ./querypie/"$QP_VERSION"/.env
  rm ./querypie/"$QP_VERSION"/.env.orig

  # Deprecated since 10.3.0
  if grep -q CABINET_DATA_DIR ./querypie/"$QP_VERSION"/.env; then
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

  if [[ $DOCKER == "docker" && -d /etc/logrotate.d/ && -f ./querypie/"$QP_VERSION"/logrotate ]]; then
    log::sudo cp ./querypie/"$QP_VERSION"/logrotate /etc/logrotate.d/docker-querypie
  fi
}

function install::verify_selinux() {
  echo >&2 "#"
  echo >&2 "## Verify SELinux settings"
  echo >&2 "#"
  if sestatus &>/dev/null; then
    echo >&2 "# SELinux is installed on this system."
  else
    echo >&2 "# SELinux is not found. Skipping SELinux settings verification."
    return
  fi

  if sestatus | grep "SELinux status:" | grep -q "enabled"; then
    echo >&2 "# SELinux is enabled on this system."
  else
    echo >&2 "# SELinux is disabled. Skipping SELinux settings verification."
    return
  fi

  if sestatus | grep "Current mode:" | grep -q "enforcing"; then
    echo >&2 "# The current mode of SELinux is enforcing."
  else
    echo >&2 "# The current mode of SELinux is not enforcing. Verification complete."
    sestatus | grep "Current mode:"
    return
  fi

  echo >&2 "## You may need to change the SELinux context of the ./querypie directory."
  echo >&2 "# A more permissive SELinux context (container_file_t) is required for ./querypie."
  log::do ls -dZ ./querypie
  echo >&2 "# The following sudo command is recommended:"
  echo >&2 "#   sudo chcon -Rt container_file_t ./querypie"
  echo >&2 "# Without this change, you may encounter container errors."
  if install::ask_yes "Do you want to run the above sudo chcon -Rt container_file_t ./querypie command?"; then
    log::sudo chcon -Rt container_file_t ./querypie
  else
    echo >&2 "# Understood. The sudo chcon command will not be executed."
  fi
}

function install::base_url() {
  local scheme=$1 compose_yml bind_port ip_addr yaml

  for yaml in \
    ./querypie/${QP_VERSION}/compose.yml \
    ./querypie/${QP_VERSION}/docker-compose.yml \
    compose.yml docker-compose.yml; do
    if [[ -f $yaml ]]; then
      compose_yml=$yaml
      break
    fi
  done

  if [[ $scheme == http ]]; then
    bind_port=$(grep -E ':80"?$' "$compose_yml" 2>/dev/null || true)
    bind_port=${bind_port#*- }
    bind_port=${bind_port#*\"}
    bind_port=${bind_port%%:*}
  else
    bind_port=$(grep -E ':443"?$' "$compose_yml" 2>/dev/null || true)
    bind_port=${bind_port#*- }
    bind_port=${bind_port#*\"}
    bind_port=${bind_port%%:*}
  fi

  # The default values when bind_port could not be found in compose.yml
  if [[ -z $bind_port ]]; then
    if [[ $scheme == http ]]; then
      bind_port="80"
    else
      bind_port="443"
    fi
  fi

  if command -v ip >/dev/null 2>&1; then
    ip_addr=$(ip route get 8.8.8.8 | grep -oP 'src \K[\d.]+')
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    local iface
    iface=$(route get default | awk '/interface:/ {print $2}')
    ip_addr=$(ipconfig getifaddr "$iface")
  else
    ip_addr=$(hostname -i)
  fi

  echo "${scheme}://${ip_addr}:${bind_port}"
}

################################################################################
# env_file related functions

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
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    # zsh: use (P) for indirect expansion
    # shellcheck disable=SC2296,SC2086
    if [[ ${(P)name+_} ]]; then
      print -r -- ${(P)name}
      return
    fi
  else
    # bash: use indirect expansion
    if [[ -n "${!name+_}" ]]; then
      echo "${!name}"
      return
    fi
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
  done 9<"${source_env}" # 9 is an unused file descriptor to read ${source_env}.
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
  ${DOCKER} inspect --format '{{.Config.Image}}' $container 2>/dev/null | cut -d':' -f2
}

function verify::container_is_ready_for_service() {
  echo >&2 "## Verify the QueryPie app container is running properly"

  local container=querypie-app-1
  if log::do $DOCKER inspect --format '{{.State.Running}}' $container 2>/dev/null | grep -q 'true'; then
    echo >&2 "# QueryPie app container, $container is running."
  else
    log::error "QueryPie app container, $container is not running. Please check the installation."
    return 1
  fi

  # Find out the version of the QueryPie app container.
  echo >&2 "# QueryPie version: $(verify::version_of_container || true)"

  if log::do $DOCKER exec querypie-app-1 readyz wait; then
    echo >&2 "# QueryPie app container, $container is ready for service."
  else
    log::error "QueryPie app container is not functioning properly. Please check the installation."
    return 1
  fi
}

function verify::mysql_data() {
  if [[ -d ./querypie/mysql ]]; then
    echo "./querypie/mysql"
  fi
}

################################################################################
# Commands

function install::get_package_version() {
  local package_version=$1 image_version=$2 major minor rest
  if [[ -n "$package_version" ]]; then
    # If package_version is provided, return it directly.
    echo "$package_version"
  # Typically, the image version is in the format of 'major.minor.patch'.
  elif [[ "$image_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    major="${image_version%%.*}" # Remove everything after the first dot.
    rest="${image_version#*.}"   # Remove everything before the first dot.
    minor="${rest%%.*}"          # Remove everything after the second dot.
    echo "${major}.${minor}.x"
  else
    # If the version does not match the expected format, use 'universal'.
    echo universal
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

function install::enable_systemd_service_for_rootless_podman() {
  if [[ $DOCKER != "podman" ]]; then
    echo >&2 "## Skip enabling systemd service for rootless Podman since Docker is used."
    return
  fi
  local rootless
  rootless=$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)
  if [[ $rootless != true ]]; then
    echo >&2 "## Skip enabling systemd service for rootless Podman since Podman is not running in rootless mode."
    return
  fi

  echo >&2 "## Enable systemd service for rootless Podman"
  local linger
  linger=$(loginctl show-user "$USER" | grep Linger= | cut -d'=' -f2)
  if [[ $linger == yes ]]; then
    echo >&2 "# Linger is already enabled for user $USER."
  else
    echo >&2 "# Enabling linger for user $USER."
    log::sudo loginctl enable-linger "$USER"
  fi

  echo >&2 "# Enabling and starting podman-querypie-database.service and podman-querypie-app.service"
  log::do systemctl --user link querypie/current/systemd/podman-querypie-database.service
  log::do systemctl --user link querypie/current/systemd/podman-querypie-app.service

  log::do systemctl --user enable --now podman-querypie-database.service
  log::do systemctl --user enable --now podman-querypie-app.service
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

  printf 'Do you agree? [y/N] : '
  local answer
  read -r answer # zsh compatibility: zsh does not support read -p prompt.
  case "${answer}" in
  y | Y | yes | YES | Yes) return ;;
  *) return 1 ;;
  esac
}

function install::load_image_from_tarball_in_offline() {
  if [[ ! -f ${OFFLINE_DIR}/images.txt ]]; then
    echo >&2 "#"
    echo >&2 "## No ${OFFLINE_DIR}/images.txt file found. Skipping loading Docker images from tarball files."
    echo >&2 "#"
    return 1
  fi

  echo >&2 "#"
  echo >&2 "## Load Docker images from tarball files listed in ${OFFLINE_DIR}/images.txt"
  echo >&2 "# Such behavior is intended for closed or air-gapped environments."
  echo >&2 "#"
  pushd "${OFFLINE_DIR}"

  local image tarball hardware normalized
  hardware=$(uname -m | tr '[:upper:]' '[:lower:]')
  # Linux: x86_64, aarch64
  # macOS: x86_64, arm64
  # Container platform: linux/amd64, linux/arm64
  case "$hardware" in
  aarch64) normalized=arm64 ;;
  arm64) normalized=arm64 ;;
  x86_64) normalized=amd64 ;;
  amd64) normalized=amd64 ;;
  *)
    log::error "Unsupported hardware architecture: $hardware"
    exit 1
    ;;
  esac
  while IFS= read -r image; do
    # Skip empty lines and comments.
    [[ -z "$image" || "$image" =~ ^\s*# ]] && continue

    tarball=$(echo "$image" | tr '/:' '__')-${normalized}.tar
    if [[ -r "$tarball" ]]; then
      echo >&2 "# Loading image $image from $tarball"
      log::do $DOCKER load -i "$tarball"
    else
      log::error "The specified tarball file, $tarball, does not exist or is not readable."
      exit 1
    fi
  done <images.txt
  log::do $DOCKER image ls
  popd
}

function cmd::install() {
  local QP_VERSION=${1:-} loaded_from_tarball=true

  echo >&2 "### Install QueryPie ###"
  echo >&2 "# QP_VERSION: ${QP_VERSION}"
  PACKAGE_VERSION=$(install::get_package_version "${PACKAGE_VERSION:-}" "${QP_VERSION}")
  echo >&2 "# PACKAGE_VERSION: ${PACKAGE_VERSION}"

  setup::sudo_privileges
  install::docker_or_podman
  install::docker_compose
  install::config_files
  install::verify_selinux
  install::load_image_from_tarball_in_offline || loaded_from_tarball=false

  echo >&2 "## Configure the .env file in ./querypie/${QP_VERSION}/"
  log::do pushd "./querypie/${QP_VERSION}/"
  cmd::populate_env ".env"

  local pull_option=''
  [[ $COMPOSE == docker-compose && ! -t 0 ]] && pull_option='--quiet'
  [[ $loaded_from_tarball == true ]] ||
    log::do $DOCKER compose --profile database --profile querypie --profile tools pull $pull_option

  echo >&2 "## Start MySQL and Redis services for QueryPie"
  log::do $DOCKER compose --profile database up --detach
  log::do sleep 20 # TODO(JK): Utilize wait-for-mysqld later.
  log::do $DOCKER compose --profile tools up --detach
  log::do tools::wait_and_print_banner

  echo >&2 "## Run migrate.sh to initialize MySQL database for QueryPie"
  echo >&2 "# This process may take more than a minute if this is the first installation."
  # Save the long output of migrate.sh as querypie-migrate.1.log
  log::do $DOCKER exec querypie-tools-1 /app/script/migrate.sh runall |
    tee ~/querypie-migrate.1.log |
    while IFS= read -r; do printf "." >&2; done
  echo >&2 " Done."
  # Run migrate.sh again to ensure the migration is completed properly
  log::do $DOCKER exec querypie-tools-1 /app/script/migrate.sh runall | tee ~/querypie-migrate.log
  log::do $DOCKER compose --profile tools down
  echo >&2 "## Start the QueryPie container (initialization takes about 2 minutes)"
  log::do $DOCKER compose --profile querypie up --detach
  log::do $DOCKER exec querypie-app-1 readyz || {
    log::error "QueryPie container has failed to start up. Please check the logs."
    log::do $DOCKER logs --tail 100 querypie-app-1 || true
    exit 1
  }
  log::do popd

  install::make_symlink_of_current
  install::enable_systemd_service_for_rootless_podman

  echo >&2 "### Installation completed successfully"
  echo >&2 "### Access QueryPie at $(install::base_url http) or $(install::base_url https) in your browser"
  echo >&2 "### Determine the public IP address of your host machine if needed"
}

function cmd::install_container_engine_only() {
  echo >&2 "### Install Container Engine only"
  echo >&2 "#"

  setup::sudo_privileges
  if install::docker_or_podman; then
    echo >&2 "# The system has a container engine already."
  elif [[ $? == 7 ]]; then
    echo >&2 "# Now it will shutdown ssh session to apply the changes."
    pkill -f sshd || true
  else
    log::error "Please report this problem to the technical support team of QueryPie."
    log::do uname -a
    exit 1
  fi
}

function cmd::install_compose_package() {
  local QP_VERSION=${1:-}

  echo >&2 "### Install Compose package only"
  echo >&2 "## This command is compatible with setup.sh (v1), which installs docker-compose package only."
  echo >&2 "# QP_VERSION: ${QP_VERSION}"
  PACKAGE_VERSION=$(install::get_package_version "${PACKAGE_VERSION:-}" "${QP_VERSION}")
  echo >&2 "# PACKAGE_VERSION: ${PACKAGE_VERSION}"

  setup::sudo_privileges
  install::docker_or_podman
  install::docker_compose
  install::config_files
  install::verify_selinux
  install::load_image_from_tarball_in_offline || true
  # Skip running of containers and services.
  echo >&2 "### Installation completed successfully"
}

function cmd::upgrade() {
  local QP_VERSION=${1:-} current_version container_version loaded_from_tarball=true

  echo >&2 "### Upgrade QueryPie to ${QP_VERSION} ###"
  echo >&2 "# QP_VERSION: ${QP_VERSION}"
  PACKAGE_VERSION=$(install::get_package_version "${PACKAGE_VERSION:-}" "${QP_VERSION}")
  echo >&2 "# PACKAGE_VERSION: ${PACKAGE_VERSION}"

  verify::container_engine_installation
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
  install::load_image_from_tarball_in_offline || loaded_from_tarball=false

  echo >&2 "## Configure the .env file in ./querypie/${QP_VERSION}/"
  log::do pushd "./querypie/${QP_VERSION}/"
  (
    if [[ -e ../current/.env ]]; then
      # shellcheck disable=SC1091
      source ../current/.env
    elif [[ -e ../current/compose-env ]]; then
      # shellcheck disable=SC1091
      source ../current/compose-env
    else
      log::error "No .env or compose-env file found in ./querypie/current/."
      exit 1
    fi
    VERSION="${QP_VERSION}" # Set the VERSION variable to the target version.
    cmd::populate_env ".env"
  )

  echo >&2 "## Download Docker images for the target version"
  local pull_option=''
  [[ $COMPOSE == docker-compose && ! -t 0 ]] && pull_option='--quiet'
  [[ $loaded_from_tarball == true ]] ||
    log::do $DOCKER compose --profile database --profile querypie --profile tools pull $pull_option
  log::do popd

  echo >&2 "## Stop containers from the previous version"
  log::do pushd "./querypie/${current_version}/"
  log::do $DOCKER compose --profile querypie down
  log::do $DOCKER compose --profile tools down || true
  log::do popd

  echo >&2 "## Start the querypie-tools container for the target version"
  log::do pushd "./querypie/${QP_VERSION}/"
  log::do $DOCKER compose --profile tools up --detach
  log::do tools::wait_and_print_banner

  echo >&2 "## Run migrate.sh to apply MySQL schema changes for QueryPie"
  # Save the long output of migrate.sh as querypie-migrate.1.log
  log::do $DOCKER exec querypie-tools-1 /app/script/migrate.sh runall >>~/querypie-migrate.1.log
  # Run migrate.sh again to ensure the migration is completed properly
  log::do $DOCKER exec querypie-tools-1 /app/script/migrate.sh runall | tee -a ~/querypie-migrate.log
  log::do $DOCKER compose --profile tools down
  echo >&2 "## Start the QueryPie container (initialization takes about 2 minutes)"
  log::do $DOCKER compose --profile querypie up --detach
  log::do $DOCKER exec querypie-app-1 readyz || {
    log::error "QueryPie container has failed to start up. Please check the logs."
    log::do $DOCKER logs --tail 100 querypie-app-1 || true
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

  echo >&2 "### Upgrade completed successfully"
  echo >&2 "### Access QueryPie at $(install::base_url http) or $(install::base_url https) in your browser"
  echo >&2 "### Determine the public IP address of your host machine if needed"
}

function cmd::uninstall() {
  echo >&2 "### Uninstall QueryPie ###"

  local current_version mysql_data container_version
  container_version=$(verify::version_of_container) || true

  echo >&2 "# Container version: ${container_version:-(Unknown! Probably QueryPie is not running)}"
  for container in querypie-app-1 querypie-tools-1 querypie-redis-1 querypie-mysql-1; do
    if $DOCKER inspect --format '{{.State.Running}}' $container &>/dev/null; then
      log::do $DOCKER stop $container
      log::do $DOCKER rm $container
    else
      echo >&2 "# Container '$container' does not exist."
    fi
  done

  mysql_data=$(verify::mysql_data)
  echo >&2 "# MySQL data: ${mysql_data:-(Unknown! MySQL is not running locally)}"
  if [[ -n "$mysql_data" ]]; then
    log::sudo rm -rf "$mysql_data"
  fi

  current_version=$(verify::version_of_current 2>/dev/null) || true
  echo >&2 "# Current version: ${current_version:-(Unknown! Probably QueryPie is not running)}"
  if [[ -n "$current_version" ]]; then
    echo >&2 "# Current directory: ./querypie/${current_version}/"
    log::do rm -rf ./querypie/"$current_version"
    log::do rm -f ./querypie/current
  fi

  echo >&2 "## Uninstall completed successfully"
}

function cmd::install_partially_for_ami() {
  local QP_VERSION=${1}

  echo >&2 "### Perform partial installation for AWS AMI Build ###"
  echo >&2 "# QP_VERSION: ${QP_VERSION}"
  PACKAGE_VERSION=$(install::get_package_version "${PACKAGE_VERSION:-}" "${QP_VERSION}")
  echo >&2 "# PACKAGE_VERSION: ${PACKAGE_VERSION}"

  setup::sudo_privileges
  install::docker_or_podman
  install::docker_compose
  install::config_files

  log::do pushd "./querypie/${QP_VERSION}/"
  cmd::populate_env ".env"

  local pull_option=''
  [[ $COMPOSE == docker-compose && ! -t 0 ]] && pull_option='--quiet'
  log::do $DOCKER compose --profile database --profile querypie --profile tools pull $pull_option
  log::do $DOCKER image ls
  cmd::reset_credential ".env"
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

  verify::container_engine_installation

  log::do pushd "./querypie/${QP_VERSION}/"
  cmd::populate_env ".env"
  log::do $DOCKER compose --profile database up --detach
  log::do sleep 10
  log::do $DOCKER compose --profile tools up --detach
  log::do tools::wait_and_print_banner

  # Save the long output of migrate.sh as querypie-migrate.1.log
  log::do $DOCKER exec querypie-tools-1 /app/script/migrate.sh runall >~/querypie-migrate.1.log
  # Run migrate.sh again to ensure the migration is completed properly
  log::do $DOCKER exec querypie-tools-1 /app/script/migrate.sh runall | tee ~/querypie-migrate.log
  log::do $DOCKER compose --profile tools down
  log::do $DOCKER compose --profile querypie up --detach
  log::do $DOCKER container ls --all
  log::do popd

  install::make_symlink_of_current

  echo >&2 "### Installation completed successfully"
}

# Populate the environment variables in the source file.
function cmd::populate_env() {
  local source_env_file=$1 tmp_file

  tmp_file=$(mktemp /tmp/env_file.XXXXXX)
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

  tmp_file=$(mktemp /tmp/env_file.XXXXXX)
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

  verify::container_engine_installation

  local container_version current_version
  current_version=$(verify::version_of_current)
  container_version=$(verify::version_of_container)
  echo >&2 "# Container version: ${container_version}"
  echo >&2 "# Current of ./querypie/current: ${current_version}"
  if [[ $container_version == "$current_version" ]]; then
    echo >&2 "# The container version is the same as the current version."
    echo >&2 "# The installation looks good so far."
  else
    log::error "The container version and the current version of ./querypie/current/ do not match."
    log::error "Please make sure that you are running the correct version of QueryPie."
    ((status += 1))
  fi

  verify::container_is_ready_for_service || {
    log::do $DOCKER logs --tail 100 querypie-app-1 || true
    ((status += 1))
  }

  if [[ status -gt 0 ]]; then
    echo >&2 "## Installation verification failed with ${status} error(s). Please check the logs for details."
    echo >&2 "# Resolve the identified issues before proceeding."
    exit "${status}"
  else
    echo >&2 "## Installation verification completed successfully."
  fi
}

function cmd::verify_not_installed() {
  echo >&2 "#"
  echo >&2 "### Verify QueryPie is not installed on this machine"
  echo >&2 "#"
  local status=0

  if [[ -d ./querypie ]]; then
    echo >&2 "# ./querypie directory exists."

    if [[ -e ./querypie/current ]]; then
      log::warning "./querypie/current symbolic link exists."
      ((status += 1))

      # Check if the version can be determined.
      if verify::version_of_current &>/dev/null; then
        log::warning "./querypie/current/ points to a directory, $(verify::version_of_current)."
        ((status += 1))
      fi
    else
      echo >&2 "# ./querypie/current symbolic link does not exist."
    fi

    if [[ -d ./querypie/mysql ]]; then
      log::warning "./querypie/mysql/ directory exists."
      ((status += 1))
      log::do ls -al ./querypie/mysql/
    else
      echo >&2 "# ./querypie/mysql/ directory does not exist."
    fi
  else
    echo >&2 "# ./querypie directory does not exist."
  fi

  local container_version
  container_version=$(verify::version_of_container) || true
  if [[ -n "$container_version" ]]; then
    log::warning "Container version: ${container_version}"
    ((status += 1))
  fi

  local container
  for container in querypie-app-1 querypie-tools-1 querypie-redis-1 querypie-mysql-1; do
    if $DOCKER inspect --format '{{.State.Running}}' $container &>/dev/null; then
      log::warning "Container '${container}' exists."
      ((status += 1))
    else
      echo >&2 "# Container '${container}' does not exist."
    fi
  done

  if [[ status -gt 0 ]]; then
    echo >&2 "## Not-installed verification failed with ${status} error(s). Please check the logs for details."
    exit "${status}"
  else
    echo >&2 "## Not-installed verification completed successfully."
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
      echo >&2 "# Directory ./querypie/ exists, but a symbolic link 'current' pointing to the current version is missing."
      if [[ -e ./querypie/current ]]; then
        log::do rm -rf ./querypie/current
      fi
      install::ask_yes "Do you want to install QueryPie (${RECOMMENDED_VERSION})?"
      cmd::install "${RECOMMENDED_VERSION}"
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

  if [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return
  else
    log::warning "Unexpected version format: ${version}"
    install::ask_yes "Do you want to install this version? ${version}"
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

function determine_offline_dir() {
  # Skip if OFFLINE_DIR is already set.
  [[ -z "${OFFLINE_DIR}" ]] || return

  local script_dir pwd_dir
  script_dir="$(cd "$(dirname "$0")" && pwd -P)"
  pwd_dir=$(pwd -P)

  if [[ $script_dir == */offline ]]; then
    OFFLINE_DIR=$script_dir
  elif [[ $pwd_dir == */offline ]]; then
    OFFLINE_DIR=$pwd_dir
  else
    OFFLINE_DIR=./offline
  fi
}

function main() {
  # PACKAGE_VERSION has a default value of 'universal' if not set as an environment variable.
  PACKAGE_VERSION=${PACKAGE_VERSION:-universal}
  DOCKER_REGISTRY=${DOCKER_REGISTRY:-docker.io/querypie/}
  USER=${USER:-$(id -un)}
  OFFLINE_DIR=${OFFLINE_DIR:-}
  local -a arguments=() # argv is reserved for zsh.
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
    --install | --install-container-engine | --install-compose-package)
      cmd="${1#--}"
      shift
      ;;
    --upgrade | --uninstall)
      cmd="${1#--}"
      shift
      ;;
    --universal)
      # Obsolete option, kept for backward compatibility.
      PACKAGE_VERSION=universal
      shift
      ;;
    --install-partially-for-ami | --resume)
      cmd="${1#--}"
      shift
      ;;
    --verify-installation | --verify-not-installed)
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
      arguments+=("$1")
      shift
      ;;
    esac
  done

  if [[ ${#arguments[@]} -gt 0 ]]; then
    set -- "${arguments[@]}"
  else
    set --
  fi

  determine_offline_dir

  case "$cmd" in
  install_recommended)
    cmd::install_recommended
    ;;
  install)
    require::version "$@"
    cmd::install "$@"
    ;;
  install-container-engine)
    cmd::install_container_engine_only
    ;;
  install-compose-package)
    require::version "$@"
    cmd::install_compose_package "$@"
    ;;
  upgrade)
    require::version "$@"
    cmd::upgrade "$@"
    ;;
  uninstall)
    cmd::uninstall "$@"
    ;;
  # FOR AWS AMI BUILD MAINTAINER
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
  verify-not-installed)
    cmd::verify_not_installed
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
