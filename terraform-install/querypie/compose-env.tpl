# Version of QueryPie Docker Image to run
VERSION=${QUERYPIE_VERSION}

# Common
## Secret key for encrypting communication between QueryPie client agents and QueryPie over port 9000/tcp.
## Must be exactly 32 characters in length.
## This will be generated during installation using: openssl rand -hex 16
AGENT_SECRET="${AGENT_SECRET}"

## Secret key used to encrypt sensitive information, such as database connection strings and SSH private keys.
## This key can be any string but is immutable once set.
## This will be generated during installation using: openssl rand -base64 32
KEY_ENCRYPTION_KEY="${KEY_ENCRYPTION_KEY}"

## The base URL of QueryPie, starting with either http:// or https://.
## This URL is used by externally provisioned components like client agents, server agents, and download links to connect QueryPie APIs.
## NOTE: This environment variable is deprecated as of version 10.2.8, and it has been replaced by specifying the Web Base URL in the General menu.
QUERYPIE_WEB_URL=${QUERYPIE_HOST}

## The AWS Account ID currently provisioned for QueryPie.
## This ID is used for provisioning the AWS Cross-Account Role.
## You can set using AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}

# DB
DB_HOST=${DB_HOST}
DB_PORT=3306
DB_CATALOG=querypie
LOG_DB_CATALOG=$${DB_CATALOG}_log
ENG_DB_CATALOG=$${DB_CATALOG}_snapshot
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD="${DB_PASSWORD}"
DB_MAX_CONNECTION_SIZE=20
## If you're using AWS Aurora, use the software.amazon.jdbc.Driver instead of org.mariadb.jdbc.Driver for automatic failover handling.
DB_DRIVER_CLASS=org.mariadb.jdbc.Driver

# Redis
## Up to 10.2.0, REDIS_HOST, REDIS_PORT must be used instead of REDIS_NODES.
## In 10.2.1 or higher it should be replaced by REDIS_NODES, but both REDIS_HOST/PORT and REDIS_NODES are supported for a while.
## REDIS_CONNECTION_MODE supports STANDALONE and CLUSTER values.
## REDIS_NODES is set as a "Host:Port" combination. When entering multiple NODEs in CLUSTER MODE, separate each NODE address with ",".
REDIS_CONNECTION_MODE=${REDIS_CONNECTION_MODE}
REDIS_NODES=${REDIS_NODES}
REDIS_PASSWORD="${REDIS_PASSWORD}"

# Skip SQL Command Rule File
DAC_SKIP_SQL_COMMAND_RULE_FILE=skip_command_config.json

# Cabinet
CABINET_DATA_DIR=/data
