#!/usr/bin/env bash
# configure-proxy.sh — QueryPie ACP Post-Installation Proxy Setup
#
# This script automates the proxy address configuration step of the
# QueryPie ACP post-installation setup guide:
#   https://docs.querypie.com/ko/installation/post-installation-setup
#
# Covered by this script:
#   - DAC/SAC proxy address  (UPDATE querypie.proxies)
#   - KAC proxy address      (UPDATE querypie.k_proxy_setting)
#
# Not covered (requires Admin Page UI):
#   - QueryPie Web Base URL  (Admin Page → General)
#   - WAC proxy address      (Admin Page → Web Apps → Web App Configurations)
#
# Usage:
#   ./configure-proxy.sh [OPTIONS] [PROXY_ADDRESS]
#
#   PROXY_ADDRESS  FQDN or IPv4 address of this host (e.g. 192.168.1.100 or querypie.example.com).
#                  If omitted, the host IP is auto-detected.
#   --yes          Assume yes to all prompts and run non-interactively.
set -o nounset -o errexit -o errtrace -o pipefail

ASSUME_YES=false

function print_usage_and_exit() {
    local code=${1:-0} out=2
    [[ code -eq 0 ]] && out=1
    cat >&"${out}" <<END_OF_USAGE
Usage: $0 [OPTIONS] [PROXY_ADDRESS]

Configure QueryPie ACP proxy settings for DAC/SAC and KAC in one step.

ARGUMENTS:
  PROXY_ADDRESS  FQDN or IPv4 address of this host.
                 e.g. 192.168.1.100, querypie.example.com
                 If omitted, the host IP is auto-detected.

OPTIONS:
  -y, --yes      Assume yes to all prompts; run non-interactively.
  -h, --help     Show this help message

END_OF_USAGE
    exit "$code"
}

# --- Colors ---
readonly BOLD_CYAN="\e[1;36m"
readonly BOLD_GREEN="\e[1;32m"
readonly BOLD_RED="\e[1;91m"
readonly RESET="\e[0m"

function log::info()  { printf "%b[INFO]%b %s\n"  "$BOLD_CYAN"  "$RESET" "$*"; }
function log::ok()    { printf "%b[OK]%b %s\n"    "$BOLD_GREEN" "$RESET" "$*"; }
function log::error() { printf "%b[ERROR]%b %s\n" "$BOLD_RED"   "$RESET" "$*" >&2; }

function log::do() {
    # shellcheck disable=SC2064
    trap "log::error 'Failed to run: $*'" ERR
    printf "%b+ %s%b\n" "$BOLD_CYAN" "$*" "$RESET" >&2
    "$@"
}

# --- Interactive confirmation ---
# Adapted from install::ask_yes in setup.v2.sh.
# Respects ASSUME_YES: when true, prints "yes" and returns 0 without prompting.
function ask_yes() {
    echo "$@" >&2
    if [[ "${ASSUME_YES}" == true ]]; then
        printf 'Do you agree? [y/N] : yes\n'
        return 0
    fi
    if [[ ! -t 0 ]]; then
        log::error "Standard input is not a terminal. Unable to receive user input."
        log::error "Run interactively, or pass --yes to skip confirmations."
        return 1
    fi
    printf 'Do you agree? [y/N] : '
    local answer
    read -r answer
    case "${answer}" in
        y|Y|yes|YES|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

# --- Validate proxy address ---
# Accepts IPv4 (e.g. 192.168.1.100) or FQDN/hostname (e.g. querypie.example.com).
# Rejects any input containing a scheme (http://, https://).
function validate_proxy_address() {
    local input="$1"

    if [[ "${input}" =~ ^https?:// ]]; then
        log::error "Proxy address must not include a scheme. Got: ${input}"
        log::error "Example: 192.168.1.100 or querypie.example.com"
        return 1
    fi

    # IPv4: format check then range check (each octet must be 0-255)
    if [[ "${input}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local IFS='.' octet
        for octet in ${input}; do
            if [[ $octet -gt 255 ]]; then
                log::error "Invalid IPv4 address: ${input} (octet ${octet} is out of range)"
                return 1
            fi
        done
        return 0
    fi

    # FQDN or hostname: labels of alphanumerics and hyphens, separated by dots
    if [[ "${input}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        return 0
    fi

    log::error "Invalid proxy address: ${input}"
    log::error "Must be an IPv4 address (e.g. 192.168.1.100) or FQDN (e.g. querypie.example.com)."
    return 1
}

# --- Detect container engine ---
# Prefers the engine where querypie-app-1 is running.
# Falls back to the engine that merely has the container (stopped),
# so require_container_running can report a helpful error.
function detect_container_engine() {
    if docker inspect --format '{{.State.Running}}' querypie-app-1 2>/dev/null | grep -q "^true$"; then
        DOCKER=docker
    elif podman inspect --format '{{.State.Running}}' querypie-app-1 2>/dev/null | grep -q "^true$"; then
        DOCKER=podman
    elif docker inspect querypie-app-1 >/dev/null 2>&1; then
        DOCKER=docker
    elif podman inspect querypie-app-1 >/dev/null 2>&1; then
        DOCKER=podman
    else
        log::error "querypie-app-1 container not found in docker or podman."
        log::error "Ensure QueryPie is deployed before running this script."
        exit 1
    fi
}

# --- Require container running ---
# Called immediately before exec/restart. Exits with guidance if stopped.
function require_container_running() {
    local state
    state=$("${DOCKER}" inspect --format '{{.State.Status}}' querypie-app-1 2>/dev/null || echo "unknown")
    if [[ "${state}" != "running" ]]; then
        log::error "querypie-app-1 is ${state}, not running."
        log::error "Start it first: ${DOCKER} start querypie-app-1"
        exit 1
    fi
}

# --- Detect host IP ---
# Adapted from install::base_url in setup.v2.sh.
function detect_host_ip() {
    local ip_addr
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local iface
        iface=$(route get default | awk '/interface:/ {print $2}')
        ip_addr=$(ipconfig getifaddr "$iface")
    elif command -v ip >/dev/null 2>&1; then
        ip_addr=$(ip route get 8.8.8.8 | grep -oP 'src \K[\d.]+')
    else
        ip_addr=$(hostname -i)
    fi
    echo "${ip_addr:-}"
}

# --- Service restart ---
function restart_services() {
    require_container_running
    log::do "${DOCKER}" restart querypie-app-1
    log::info "Waiting for app to be ready..."
    log::do "${DOCKER}" exec querypie-app-1 readyz wait
    log::ok "App is ready."
}

# --- SQL executor ---
# Runs SQL inside querypie-app-1 using the container's own DB credentials.
function run_sql() {
    local sql="$1"
    require_container_running
    printf "%b+ [querypie-app-1] mariadb -e \"%s\"%b\n" "$BOLD_CYAN" "$sql" "$RESET" >&2
    "${DOCKER}" exec querypie-app-1 \
        sh -c 'mariadb --ssl=FALSE -h"${DB_HOST}" -u"${DB_USERNAME}" -p"${DB_PASSWORD}" -D"${DB_CATALOG}" -e "$1"' \
        sh "${sql}"
}

# --- DAC/SAC proxy configuration ---
# Ref: https://docs.querypie.com/ko/installation/post-installation-setup
# Note: DAC/SAC proxy address must NOT include a scheme (no http:// or https://).
function configure_dac_sac() {
    local host="$1"
    log::info "Configuring DAC/SAC proxy: ${host}"
    run_sql "UPDATE proxies SET host = '${host}' WHERE id = 1;"
    log::ok "DAC/SAC proxy updated."
    run_sql "SELECT id, host FROM proxies WHERE id = 1;"
}

# --- KAC proxy configuration ---
# Ref: https://docs.querypie.com/ko/installation/post-installation-setup
# Note: KAC proxy address must include https:// (http:// is not supported).
#       A container restart is required after this change for TLS certificate issuance.
function configure_kac() {
    local host="$1"
    log::info "Configuring KAC proxy: ${host}"
    run_sql "UPDATE k_proxy_setting SET host = '${host}';"
    log::ok "KAC proxy updated."
    run_sql "SELECT host FROM k_proxy_setting;"
}

# --- Main ---
function main() {
    # Parse arguments first so --help works without a TTY.
    local -a arguments=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) print_usage_and_exit 0 ;;
            -y|--yes) ASSUME_YES=true; shift ;;
            --) shift; arguments+=("$@"); break ;;
            -*) log::error "Unexpected option: $1"; print_usage_and_exit 1 ;;
            *) arguments+=("$1"); shift ;;
        esac
    done

    if [[ ${#arguments[@]} -gt 1 ]]; then
        log::error "Too many arguments."
        print_usage_and_exit 1
    fi

    local proxy_input="${arguments[0]:-}"

    # Detect container engine (DOCKER is global: used by run_sql, restart_services)
    detect_container_engine

    # Resolve proxy address
    if [[ -z "${proxy_input}" ]]; then
        local detected_ip
        detected_ip=$(detect_host_ip)
        if [[ "${ASSUME_YES}" == true ]]; then
            # Non-interactive: use auto-detected IP without prompting.
            proxy_input="${detected_ip}"
            if [[ -z "${proxy_input}" ]]; then
                log::error "Could not auto-detect host IP. Provide PROXY_ADDRESS as an argument."
                exit 1
            fi
            log::info "Using auto-detected proxy address: ${proxy_input}"
        elif [[ -n "${detected_ip}" ]]; then
            if [[ ! -t 0 ]]; then
                log::error "Standard input is not a terminal."
                log::error "Pass PROXY_ADDRESS as an argument, or use --yes to accept the auto-detected address (${detected_ip})."
                exit 1
            fi
            read -rp "Proxy address [${detected_ip}]: " proxy_input
            proxy_input="${proxy_input:-${detected_ip}}"
        else
            if [[ ! -t 0 ]]; then
                log::error "Standard input is not a terminal and host IP could not be auto-detected."
                log::error "Provide PROXY_ADDRESS as an argument."
                exit 1
            fi
            read -rp "Proxy address: " proxy_input
        fi
        if [[ -z "${proxy_input}" ]]; then
            log::error "Proxy address is required."
            exit 1
        fi
    fi

    validate_proxy_address "${proxy_input}" || exit 1

    # Derive per-product addresses:
    #   DAC/SAC requires no scheme (e.g. 192.168.1.100)
    #   KAC requires a scheme     (e.g. https://192.168.1.100)
    local dac_host="${proxy_input}"
    local kac_host="https://${proxy_input}"

    # Show plan and confirm
    echo ""
    log::info "Proxy settings to apply:"
    printf "  DAC/SAC : %s\n" "${dac_host}"
    printf "  KAC     : %s\n" "${kac_host}"
    echo ""
    if ! ask_yes "Apply the above proxy settings?"; then
        log::info "Aborted."
        exit 0
    fi

    # Apply proxy settings
    echo ""
    configure_dac_sac "${dac_host}"
    echo ""
    configure_kac "${kac_host}"

    # Restart prompt
    echo ""
    if ask_yes "Restart services to apply changes?"; then
        restart_services
    else
        log::info "Skipping restart. Remember to restart services manually to apply changes."
    fi

    echo ""
    log::ok "Done."
}

# Guard: allows sourcing this file in bats tests without executing main.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
