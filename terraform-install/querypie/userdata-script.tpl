#!/bin/bash -ex

# Enable error handling with nounset to catch unbound variables
set -o errexit
set -o pipefail
set -o nounset

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
echo BEGIN

# Variables
QP_TEMPDIR=$(mktemp -d)
QP_BASEDIR=${OS_HOME_DIR}/querypie
QP_VERSION=${QUERYPIE_VERSION}
DOWNLOAD_VERSION=$${QP_VERSION%.*}.x
QUERYPIE_USER=${OS_USER}
QUERYPIE_HOST=${QUERYPIE_HOST}
QUERYPIE_PROXY_HOST=${QUERYPIE_PROXY_HOST}
OS_TYPE=${OS_TYPE}
OS_USER=${OS_USER}
OS_HOME_DIR=${OS_HOME_DIR}
USE_EXTERNALDB=${USE_EXTERNALDB}
USE_EXTERNALREDIS=${USE_EXTERNALREDIS}
DB_HOST=${DB_HOST}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME="querypie"
REDIS_CONNECTION_MODE=${REDIS_CONNECTION_MODE}
REDIS_NODES=${REDIS_NODES}
REDIS_PASSWORD=${REDIS_PASSWORD}

# Color codes for better readability in logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

if [ -z $QUERYPIE_HOST ]; then
    QUERYPIE_HOST=$(curl -sL https://checkip.amazonaws.com)
    # QUERYPIE_HOST=$(curl -sL http://169.254.169.254/latest/meta-data/local-ipv4)
fi

# Install and configure SSM Agent
if ! command -v amazon-ssm-agent &>/dev/null; then
    echo -e "$${YELLOW}SSM Agent not found. Installing...$${NC}"
    if [ $OS_TYPE = "ubuntu" ]; then
        apt-get update
        apt-get install -y amazon-ssm-agent
    elif command -v dnf &>/dev/null; then
        dnf install -y amazon-ssm-agent
    else
        yum install -y amazon-ssm-agent
    fi
fi

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Execute command as ec2-user with setup
execute_cmd() {
    local CMD=$1
    pushd $QP_BASEDIR/$QP_VERSION
    source compose-env
    sudo -u $QUERYPIE_USER bash -c "$CMD"
    popd
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Set package manager based on OS type
if [ $OS_TYPE = "ubuntu" ]; then
    PKG_MANAGER="apt-get"
elif command_exists dnf; then
    PKG_MANAGER="dnf"
else
    # If dnf does not exist, use yum
    PKG_MANAGER="yum"
fi

# Install Docker & Docker-compose and QueryPie
echo -e "$${YELLOW}Downloading and running QueryPie setup script as $QUERYPIE_USER...$${NC}"
cd $OS_HOME_DIR
curl -L https://dl.querypie.com/releases/compose/setup.sh -o setup.sh
chmod +x setup.sh
sudo -u $QUERYPIE_USER QP_VERSION=$QP_VERSION DOWNLOAD_VERSION=$DOWNLOAD_VERSION ./setup.sh

# Move compose-env to the installation directory
mv -f $OS_HOME_DIR/compose-env $QP_BASEDIR/$QP_VERSION/compose-env
su $QUERYPIE_USER -c "mkdir -p $OS_HOME_DIR/.docker"

# Setup Docker configuration to login to Harbor registry
echo -e "$${YELLOW}Setting up Docker configuration...$${NC}"
cat <<EOF >$OS_HOME_DIR/.docker/config.json
${DOCKER_CONFIG}
EOF

chown $QUERYPIE_USER:$QUERYPIE_USER $OS_HOME_DIR/.docker/config.json

echo -e "$${YELLOW}Creating cabinet data directory...$${NC}"
mkdir -vp /data
chown -R $QUERYPIE_USER:$QUERYPIE_USER /data

# Install MySQL Cli
echo -e "$${YELLOW}Installing MySQL client...$${NC}"
if [ $OS_TYPE = "ubuntu" ]; then
    apt-get update
    apt-get install -y mysql-client
elif command_exists dnf; then
    # Run the specific command if dnf exists
    rpm -Uvh https://repo.mysql.com/mysql80-community-release-el9.rpm
    $PKG_MANAGER install -y mysql-community-client
else
    $PKG_MANAGER install -y mysql
fi

# Set default values for database host, username, and password
if [ -z "$DB_HOST" ]; then
    DB_HOST=$QUERYPIE_HOST
    DB_USERNAME="querypie"
    DB_PASSWORD="Querypie1!"
else
    DB_USERNAME=$DB_USERNAME
    DB_PASSWORD=$DB_PASSWORD
fi

# Function to check if a database exists
check_database_exists() {
    mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -e "USE $DB_NAME;" 2>/dev/null
}

# Remove the QueryPie database, user, and permissions if necessary
remove_querypie_db_and_user() {
    mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" <<EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP DATABASE IF EXISTS ${DB_NAME}_log;
DROP DATABASE IF EXISTS ${DB_NAME}_snapshot;
DROP USER IF EXISTS '${DB_USERNAME}'@'%';
EOF
}

# Function to configure the QueryPie database, user, and permissions
configure_database() {
    echo -e "$${YELLOW}Configuring database...$${NC}"
    mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS ${DB_NAME}_log CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS ${DB_NAME}_snapshot CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'querypie' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USERNAME'@'%';
GRANT ALL PRIVILEGES ON ${DB_NAME}_log.* TO '$DB_USERNAME'@'%';
GRANT ALL PRIVILEGES ON ${DB_NAME}_snapshot.* TO '$DB_USERNAME'@'%';
FLUSH PRIVILEGES;
EOF
}

# Configure the QueryPie database if DB_HOST is set
if [ "$USE_EXTERNALDB" -eq "1" ]; then
    echo -e "$${YELLOW}Using external database at $DB_HOST...$${NC}"
    if ! check_database_exists; then
        configure_database
    fi
fi

# Run default database provided by QueryPie if DB_HOST is not set
if [ "$USE_EXTERNALDB" -eq "0" ]; then
    echo -e "$${YELLOW}Starting local database...$${NC}"
    execute_cmd "/usr/local/bin/docker-compose --env-file compose-env --profile database up -d"
fi

# Configure Redis if USE_EXTERNALREDIS is set
if [ "$USE_EXTERNALREDIS" -eq "1" ]; then
    echo -e "$${YELLOW}Using external Redis at $REDIS_NODES with mode $REDIS_CONNECTION_MODE...$${NC}"
else
    echo -e "$${YELLOW}Using local Redis...$${NC}"
fi

# Migrate QueryPie and apply license
echo -e "$${YELLOW}Starting QueryPie tools...$${NC}"
execute_cmd "/usr/local/bin/docker-compose --env-file compose-env --profile tools up -d"

echo -e "$${YELLOW}Waiting for tools to be ready...$${NC}"
until docker logs querypie-tools-1 | grep -q Started; do
    sleep 1
done

echo -e "$${YELLOW}Running database migrations...$${NC}"
# Execute docker exec and capture output and errors
docker exec querypie-tools-1 /app/script/migrate.sh runall 2>&1
EXIT_CODE=$?

echo -e "$${YELLOW}Waiting for migrations to complete. This process may take some time...$${NC}"

# Check if migration was successful
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "$${GREEN}Migration process completed successfully.$${NC}"
else
    echo -e "$${RED}An error occurred during migration. Exit code: $EXIT_CODE$${NC}"
    echo -e "$${RED}Check container logs: docker logs querypie-tools-1$${NC}"
    exit 1
fi

# Apply QueryPie License
echo -e "$${YELLOW}Applying QueryPie license...$${NC}"
license_file="${OS_HOME_DIR}/license.crt"
curl -XPOST 127.0.0.1:8050/license/upload -F "file=@$license_file"

# Update proxies table
echo -e "$${YELLOW}Updating proxy settings...$${NC}"
mysql -h$DB_HOST -u$DB_USERNAME -p$DB_PASSWORD $DB_NAME -e "update proxies set host='$QUERYPIE_PROXY_HOST', port_from=40000, port_to=40050"

# Stop QueryPie Tools
echo -e "$${YELLOW}Stopping QueryPie tools...$${NC}"
execute_cmd "/usr/local/bin/docker-compose --env-file compose-env --profile tools down"

# Start QueryPie
echo -e "$${GREEN}Starting QueryPie...$${NC}"
execute_cmd "/usr/local/bin/docker-compose --env-file compose-env --profile querypie up -d"

echo -e "$${GREEN}QueryPie installation completed successfully!$${NC}"
echo END