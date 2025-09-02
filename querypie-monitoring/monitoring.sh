#!/bin/bash

# Exit on error and undefined variables
set -e
set -o nounset

# Constants
readonly SCRIPT_NAME=$(basename "$0")
readonly GITHUB_REPO="https://github.com/querypie/tpm/archive/refs/heads/main.tar.gz"
readonly DASHBOARD_FILES=("querypie-status.json" "querypie-log.json" "querypie-cp.json")

# Get host IP address
HOST_IP=$(hostname -I | awk '{print $1}' || echo "127.0.0.1")

# Default configuration
readonly DEFAULT_MYSQL_HOST="${HOST_IP}"
readonly DEFAULT_PORT="3306"
readonly DEFAULT_MYSQL_USER="querypie"
readonly DEFAULT_MYSQL_PASS="Querypie1!"
readonly DEFAULT_MYSQL_DB="querypie_log"

# Logging functions
log_info() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

log_debug() {
  if [[ "${DEBUG:-false}" == "true" ]]; then
    echo "[DEBUG] $1"
  fi
}

# Error handling
handle_error() {
  log_error "An error occurred in ${SCRIPT_NAME} at line $1"
  exit 1
}

trap 'handle_error $LINENO' ERR

# Function to check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."

  if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed"
    exit 1
  fi

  if ! command -v docker-compose &>/dev/null; then
    log_error "Docker Compose is not installed"
    exit 1
  fi

  log_info "All prerequisites are satisfied"
}

# Function to setup monitoring directory
setup_monitoring_dir() {
  log_info "Setting up monitoring directory..."

  log_info "Downloading monitoring files..."
  curl -L "${GITHUB_REPO}" | tar -xzf - \
    --strip-components=2 \
    -C . \
    tpm-main/querypie-monitoring

  # --- 추가 시작 ---
  log_info "Setting execute permission for ${SCRIPT_NAME}..."
  chmod +x "${SCRIPT_NAME}"
  log_info "Execute permission set."
  # --- 추가 끝 ---

  log_info "Monitoring directory setup completed"
}

# Function to get QueryPie container information
get_querypie_info() {
  log_info "Getting QueryPie container information..."

  QUERYPIE_CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep 'querypie-app' || true)
  if [[ -z "${QUERYPIE_CONTAINER_NAME}" ]]; then
    log_error "QueryPie container not found"
    exit 1
  fi
  log_info "Found QueryPie container: ${QUERYPIE_CONTAINER_NAME}"

  QUERYPIE_NETWORK_NAME=$(docker inspect --format '{{range $k, $v := .NetworkSettings.Networks}}{{printf "%s" $k}}{{end}}' "${QUERYPIE_CONTAINER_NAME}")
  if [[ -z "${QUERYPIE_NETWORK_NAME}" ]]; then
    log_error "QueryPie network not found"
    exit 1
  fi
  log_info "Found QueryPie container network: ${QUERYPIE_NETWORK_NAME}"
}

# Function to setup MySQL configuration
setup_mysql_config() {
  log_info "Setting up MySQL configuration..."

  # Set default values if not provided
  MYSQL_HOST=${MYSQL_HOST:-"${DEFAULT_MYSQL_HOST}"}
  PORT=${PORT:-"${DEFAULT_PORT}"}
  MYSQL_USER=${MYSQL_USER:-"${DEFAULT_MYSQL_USER}"}
  MYSQL_PASS=${MYSQL_PASS:-"${DEFAULT_MYSQL_PASS}"}
  MYSQL_DB=${MYSQL_DB:-"${DEFAULT_MYSQL_DB}"}

  log_info "Using MySQL Host: ${MYSQL_HOST}"
  log_debug "MySQL Port: ${PORT}"
  log_debug "MySQL User: ${MYSQL_USER}"
  log_debug "MySQL Database: ${MYSQL_DB}"
}

# Function to create directory structure
create_directory_structure() {
  log_info "Creating directory structure..."

  mkdir -p prometheus \
    grafana/provisioning/datasources \
    grafana/provisioning/dashboards \
    grafana/dashboards \
    etc/procstat
}

# Function to copy dashboard files
copy_dashboard_files() {
  log_info "Copying dashboard files..."

  for dashboard in "${DASHBOARD_FILES[@]}"; do
    if [[ ! -f "${dashboard}" ]]; then
      log_error "Dashboard file ${dashboard} not found!"
      exit 1
    fi
    cp "${dashboard}" grafana/dashboards/
  done
}

# Function to create prometheus configuration
create_prometheus_config() {
  log_info "Creating Prometheus configuration..."

  cat >prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'procstat'
    static_configs:
      - targets: ['procstat:9256']
  - job_name: 'querypie'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['${QUERYPIE_CONTAINER_NAME}']
EOF
}

# Function to create procstat configuration
create_procstat_config() {
  log_info "Creating Procstat configuration..."

  cat >etc/procstat/all.yaml <<EOF
process_names:
  - name: "{{.Comm}}"
    comm:
    - ARiSA
    - QueryPie.Core
    - QueryPieGateway
    - supervisor
    - cabinet
    - kubepie-proxy
    - nginx
    - querypie-engine
    - rotatepie 
    - nginx
    cmdline:
    - '.+'
  - name: "{{.Comm}}-{{.Matches.Path}}"
    cmdline: 
    - "-jar\\\\s+.+?(?P<Path>[^/]+).jar(?:$|\\\\s)"
EOF
}

# Function to create monitoring compose file
create_monitoring_compose() {
  log_info "Creating monitoring compose file..."

  cat >monitoring.yml <<EOF
version: '3.8'
networks:
  ${QUERYPIE_NETWORK_NAME}:
    external: true
services:
  prometheus:
    image: prom/prometheus:v3.0.0
    container_name: prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--storage.tsdb.retention.size=50GB'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    networks:
      - ${QUERYPIE_NETWORK_NAME}
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    restart: unless-stopped
  grafana:
    image: grafana/grafana:12.1.1
    container_name: grafana
    ports:
      - "3000:3000"
    networks:
      - ${QUERYPIE_NETWORK_NAME}
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true
    restart: unless-stopped
  procstat:
    image: ncabatoff/process-exporter:sha-e2a9f0d
    container_name: procstat
    command:
      - "--procfs=/host/proc"
      - "--config.path=/config/all.yaml"
    ports:
      - 9256:9256
    networks:
      - ${QUERYPIE_NETWORK_NAME}
    volumes:
      - /proc:/host/proc
      - ./etc/procstat:/config
    restart: unless-stopped
volumes:
  prometheus_data:
EOF
}

# Function to create Grafana datasource configuration
create_grafana_datasource() {
  log_info "Creating Grafana datasource configuration..."

  cat >grafana/provisioning/datasources/datasource.yml <<EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    uid: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
  - name: QueryPie
    type: mysql
    uid: querypie
    url: ${MYSQL_HOST}:${PORT}
    user: ${MYSQL_USER}
    secureJsonData:
      password: "${MYSQL_PASS}"
    database: ${MYSQL_DB}
    jsonData:
      sslmode: "disable"
    isDefault: false    
EOF
}

# Function to create Grafana dashboard provisioning configuration
create_grafana_dashboard_provisioning() {
  log_info "Creating Grafana dashboard provisioning configuration..."

  cat >grafana/provisioning/dashboards/dashboards.yml <<EOF
apiVersion: 1
providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    folderUid: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF
}

# Function to setup monitoring environment
setup_monitoring() {
  log_info "Starting QueryPie monitoring setup..."

  check_prerequisites
  setup_monitoring_dir
  get_querypie_info
  setup_mysql_config
  create_directory_structure
  copy_dashboard_files
  create_prometheus_config
  create_procstat_config
  create_monitoring_compose
  create_grafana_datasource
  create_grafana_dashboard_provisioning

  log_info "Setup completed successfully!"
}

# Function to start monitoring services
start_monitoring() {
  log_info "Starting monitoring services..."

  if [[ ! -f "monitoring.yml" ]]; then
    log_error "monitoring.yml not found. Please run setup first."
    exit 1
  fi

  docker-compose -f monitoring.yml up -d
  log_info "Monitoring services started successfully!"
}

# Function to stop monitoring services
stop_monitoring() {
  log_info "Stopping monitoring services..."

  if [[ ! -f "monitoring.yml" ]]; then
    log_error "monitoring.yml not found. Please run setup first."
    exit 1
  fi

  docker-compose -f monitoring.yml down
  log_info "Monitoring services stopped successfully!"
}

# Main function
main() {
  case "${1:-}" in
  "setup")
    setup_monitoring
    ;;
  "up")
    start_monitoring
    ;;
  "down")
    stop_monitoring
    ;;
  *)
    log_error "Usage: $0 {setup|up|down}"
    exit 1
    ;;
  esac
}

# Run main function
main "$@"
