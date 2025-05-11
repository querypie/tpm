#!/bin/bash
QUERYPIE_CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep 'querypie-app')
echo "Found QueryPie container: $QUERYPIE_CONTAINER_NAME"
QUERYPIE_NETWORK_NAME=$(docker inspect --format '{{range $k, $v := .NetworkSettings.Networks}}{{printf "%s" $k}}{{end}}' $QUERYPIE_CONTAINER_NAME)
echo "Found QueryPie container network: $QUERYPIE_NETWORK_NAME"

MYSQL_HOST="172.31.7.229"
PORT="3306"
MYSQL_USER="querypie"
MYSQL_PASS="Querypie1!"
MYSQL_DB="querypie_log"

# Create directory structure
mkdir -p prometheus grafana/provisioning/datasources grafana/provisioning/dashboards grafana/dashboards etc/procstat

# Copy the dashboard JSON file
cp querypie-status.json grafana/dashboards/
cp querypie-log.json grafana/dashboards/
cp querypie-cp.json grafana/dashboards/

# Create prometheus config with the container name
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

# Create procstat configuration
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

# Create monitoring compose file
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
      - '--storage.tsdb.retention.time=15d'  # 데이터 보존 기간 (예: 15일)
      - '--storage.tsdb.retention.size=50GB' # 최대 저장 용량
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
    image: grafana/grafana:11.3.1
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

# Create Grafana datasource configuration
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

# Create Grafana dashboard provisioning configuration
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

# Check if querypie-status.json exists
if [ ! -f "querypie-status.json" ]; then
  echo "Error: querypie-status.json file not found!"
  echo "Please make sure querypie-status.json is in the current directory."
  exit 1
fi

echo "Configuration files have been created."
echo "QueryPie container name: $QUERYPIE_CONTAINER_NAME"
echo "Grafana dashboard has been configured."
echo "To start monitoring, run:"
echo "docker-compose -f monitoring.yml up -d"
echo "To stop monitoring, run:"
echo "docker-compose -f monitoring.yml down"
