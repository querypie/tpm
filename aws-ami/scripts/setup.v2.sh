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
    or $program_name [options] --resume
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

function setup_sudo_privileges() {
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

function install_docker() {
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

function install_docker_compose() {
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

function install_config_files() {
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

function validate::action_and_version() {
  local action=$1 version=$2
  case "$action" in
  install | upgrade)
    if [[ -z $version ]]; then
      log::error "Version is required for installation or upgrade."
      print_usage_and_exit 1
    fi
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      log::error "Invalid version format: $version"
      print_usage_and_exit 1
    fi
    ;;
  resume)
    # Resume does not require a version, so no validation needed.
    ;;
  *)
    log::error "Invalid action: $action"
    echo >&2 "# Valid actions are: install, upgrade, resume."
    print_usage_and_exit 1
    ;;
  esac

  if [[ -z $version ]]; then
    log::error "QP_VERSION is required. Please set QP_VERSION environment variable."
    exit 1
  elif [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log::error "Invalid version format of QP_VERSION: $version"
    echo >&2 "# QP_VERSION should be in the format of 'major.minor.patch' such as '10.2.5'."
    exit 1
  fi
}

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

function do_install() {
  local qp_version=$1
  QP_VERSION="${QP_VERSION:-${qp_version:-}}"

  validate::action_and_version install "${QP_VERSION}"
  echo >&2 "# QP_VERSION: ${QP_VERSION}"

  PACKAGE_VERSION=$(package_version "${PACKAGE_VERSION:-}" "${QP_VERSION}")
  echo >&2 "# PACKAGE_VERSION: ${PACKAGE_VERSION}"

  setup_sudo_privileges
  install_docker
  install_docker_compose
  install_config_files

  echo >&2 "### Installation is done successfully."
}

function main() {
  echo >&2 "### Welcome to QueryPie Installation! ###"

  local action="install" qp_version=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -x | --xtrace)
      set -o xtrace
      shift
      ;;
    -h | --help)
      print_usage_and_exit 0
      ;;
    --install)
      action="install"
      shift
      ;;
    --upgrade)
      action="upgrade"
      shift
      ;;
    --resume)
      action="resume"
      shift
      ;;
    -*)
      # Got unexpected arguments
      log::error "Unexpected option received: $1"
      print_usage_and_exit 1
      ;;
    [0-9]*.[0-9]*.[0-9]*)
      qp_version="$1"
      shift
      ;;
    *)
      # Got unexpected arguments
      log::error "Unexpected argument received: $1"
      log::error "Please provide the version in the format ##.##.#, such as 10.3.1"
      print_usage_and_exit 1
      ;;
    esac
  done

  case "$action" in
  install)
    do_install "$qp_version"
    ;;
  upgrade)
    echo >&2 "# Upgrade is not implemented yet."
    exit 1
    ;;
  resume)
    echo >&2 "# Resuming installation is not implemented yet."
    exit 1
    ;;
  *)
    log::error "Invalid action: $action"
    print_usage_and_exit 1
    ;;
  esac
}

main "$@"
