#!/usr/bin/env bash
set -o nounset -o errexit -o pipefail

# --- Colors ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log::info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
log::ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log::error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Detect container engine ---
if command -v docker &>/dev/null; then
    COMPOSE="docker compose"
elif command -v podman &>/dev/null; then
    COMPOSE="podman compose"
else
    log::error "Neither docker nor podman found."
    exit 1
fi

# --- Detect host IP ---
detect_host_ip() {
    hostname -I 2>/dev/null | awk '{print $1}' || echo "192.168.0.1"
}

HOST_IP=$(detect_host_ip)

# --- .env file path ---
DEFAULT_ENV_PATH="$HOME/querypie/current/.env"
read -rp "Path to .env file [${DEFAULT_ENV_PATH}]: " ENV_PATH
ENV_PATH="${ENV_PATH:-${DEFAULT_ENV_PATH}}"

if [[ ! -f "${ENV_PATH}" ]]; then
    log::error "File not found: ${ENV_PATH}"
    exit 1
fi

COMPOSE_DIR="$(dirname "${ENV_PATH}")"

# --- Read DB credentials from .env ---
DB_USERNAME=$(grep '^DB_USERNAME=' "${ENV_PATH}" | cut -d'=' -f2-)
DB_PASSWORD=$(grep '^DB_PASSWORD=' "${ENV_PATH}" | cut -d'=' -f2-)

if [[ -z "${DB_USERNAME}" || -z "${DB_PASSWORD}" ]]; then
    log::error "DB_USERNAME or DB_PASSWORD not found in .env file."
    exit 1
fi

log::info "DB user: ${DB_USERNAME}"

# --- Service restart ---
restart_services() {
    log::info "Stopping app..."
    $COMPOSE -f "${COMPOSE_DIR}/compose.yml" --profile=app stop
    log::info "Starting app..."
    $COMPOSE -f "${COMPOSE_DIR}/compose.yml" --profile=app up -d
    log::info "Verifying app readiness..."
    $COMPOSE -f "${COMPOSE_DIR}/compose.yml" --profile=app exec app readyz
}

# --- SQL executor ---
run_sql() {
    local sql="$1"
    docker exec querypie-mysql-1 mysql \
        -u"${DB_USERNAME}" -p"${DB_PASSWORD}" \
        -D querypie -e "${sql}" 2>/dev/null
}

# --- DAC/SAC proxy configuration ---
configure_dac_sac() {
    echo ""
    log::info "=== DAC/SAC Proxy Configuration ==="
    echo ""
    read -rp "Enter DAC/SAC proxy address (e.g. ${HOST_IP} or qp.example.com) [${HOST_IP}]: " PROXY_ADDRESS
    PROXY_ADDRESS="${PROXY_ADDRESS:-${HOST_IP}}"

    local sql="UPDATE querypie.proxies SET host = '${PROXY_ADDRESS}' WHERE id = 1;"
    echo ""
    log::info "SQL to execute:"
    echo "  ${sql}"
    echo ""
    read -rp "Proceed? [y/N]: " CONFIRM
    case "${CONFIRM}" in
        [yY]|[yY][eE][sS]) ;;
        *)
            log::info "Skipping DAC/SAC configuration."
            return 0
            ;;
    esac

    run_sql "${sql}"
    log::ok "DAC/SAC proxy updated."
    echo ""
    log::info "Result:"
    run_sql "SELECT id, host FROM querypie.proxies WHERE id = 1;"
}

# --- KAC proxy configuration ---
configure_kac() {
    echo ""
    log::info "=== KAC Proxy Configuration ==="
    echo ""
    local default_kac="https://${HOST_IP}"
    read -rp "Enter KAC proxy address with scheme (e.g. https://${HOST_IP} or https://kac.example.com) [${default_kac}]: " PROXY_ADDRESS
    PROXY_ADDRESS="${PROXY_ADDRESS:-${default_kac}}"

    # Validate scheme
    if [[ ! "${PROXY_ADDRESS}" =~ ^https?:// ]]; then
        log::error "Address must start with http:// or https://"
        return 1
    fi

    local kac_host="${PROXY_ADDRESS}"

    local sql="UPDATE querypie.k_proxy_setting SET host = '${kac_host}';"
    echo ""
    log::info "SQL to execute:"
    echo "  ${sql}"
    echo ""
    read -rp "Proceed? [y/N]: " CONFIRM
    case "${CONFIRM}" in
        [yY]|[yY][eE][sS]) ;;
        *)
            log::info "Skipping KAC configuration."
            return 0
            ;;
    esac

    run_sql "${sql}"
    log::ok "KAC proxy updated."
    echo ""
    log::info "Result:"
    run_sql "SELECT host FROM querypie.k_proxy_setting;"
}

# --- Menu ---
echo ""
echo "Select configuration type:"
echo "  1) DAC/SAC proxy configuration"
echo "  2) KAC proxy configuration"
echo "  3) Both (DAC/SAC + KAC)"
echo "  q) Quit"
echo ""
read -rp "Choose [1/2/3/q]: " PROXY_TYPE

case "${PROXY_TYPE}" in
    1)
        configure_dac_sac
        ;;
    2)
        configure_kac
        ;;
    3)
        configure_dac_sac
        configure_kac
        ;;
    [qQ])
        log::info "Exiting."
        exit 0
        ;;
    *)
        log::error "Invalid selection. Please enter 1, 2, 3, or q."
        exit 1
        ;;
esac

echo ""
read -rp "Restart services to apply changes? [y/N]: " RESTART
case "${RESTART}" in
    [yY]|[yY][eE][sS])
        restart_services
        ;;
    *)
        log::info "Skipping restart. Remember to restart services manually to apply changes."
        ;;
esac

echo ""
log::ok "Done."