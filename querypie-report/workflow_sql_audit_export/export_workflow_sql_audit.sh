#!/bin/bash
BASEDIR=workflows
FROM="2025-07-01 00:00:00"
TO="2026-07-01 00:00:00"
# Leave empty to export every approval rule. Use commas for multiple names.
APPROVAL_RULE_NAMES=""
# Set to true to include DML snapshot before/after data in the output.
INCLUDE_DML_SNAPSHOTS="${INCLUDE_DML_SNAPSHOTS:-false}"

# App DB connection. QUERYPIE_LOG_DB_* and QUERYPIE_SNAPSHOT_DB_* may override
# the corresponding values when those databases are hosted separately.
DB_HOST="${QUERYPIE_DB_HOST:-127.0.0.1}"
DB_PORT="${QUERYPIE_DB_PORT:-3306}"
DB_USER="${QUERYPIE_DB_USER:-querypie}"
DB_NAME="${QUERYPIE_DB_NAME:-querypie}"
LOG_DB_HOST="${QUERYPIE_LOG_DB_HOST:-$DB_HOST}"
LOG_DB_PORT="${QUERYPIE_LOG_DB_PORT:-$DB_PORT}"
LOG_DB_USER="${QUERYPIE_LOG_DB_USER:-$DB_USER}"
LOG_DB_NAME="${QUERYPIE_LOG_DB_NAME:-querypie_log}"
SNAPSHOT_DB_HOST="${QUERYPIE_SNAPSHOT_DB_HOST:-$LOG_DB_HOST}"
SNAPSHOT_DB_PORT="${QUERYPIE_SNAPSHOT_DB_PORT:-$LOG_DB_PORT}"
SNAPSHOT_DB_USER="${QUERYPIE_SNAPSHOT_DB_USER:-$LOG_DB_USER}"
SNAPSHOT_DB_NAME="${QUERYPIE_SNAPSHOT_DB_NAME:-querypie_snapshot}"
VENDOR_DIR="${QUERYPIE_AUDIT_VENDOR_DIR:-./vendor-python2}"

# Required. Set this before execution, for example:
# export QUERYPIE_DB_PASSWORD='...'
: "${QUERYPIE_DB_PASSWORD:?QUERYPIE_DB_PASSWORD must be set}"
# Optional: use a distinct credential for querypie_log when needed.
LOG_DB_PASSWORD="${QUERYPIE_LOG_DB_PASSWORD:-$QUERYPIE_DB_PASSWORD}"
SNAPSHOT_DB_PASSWORD="${QUERYPIE_SNAPSHOT_DB_PASSWORD:-$LOG_DB_PASSWORD}"

mkdir -p $BASEDIR/result
mkdir -p $BASEDIR/progress

echo " == Export =="

APPROVAL_RULE_OPTION=()
if [ -n "$APPROVAL_RULE_NAMES" ]; then
  APPROVAL_RULE_OPTION=(--approval-rule-name "$APPROVAL_RULE_NAMES")
fi

DML_SNAPSHOT_OPTION=()
if [ "$INCLUDE_DML_SNAPSHOTS" = "true" ]; then
  DML_SNAPSHOT_OPTION=(--include-dml-snapshots)
fi

VENDOR_OPTION=()
if [ -d "$VENDOR_DIR" ]; then
  VENDOR_OPTION=(--vendor-dir "$VENDOR_DIR")
fi

python2.7 export_workflow_sql_requests.py \
  --output $BASEDIR/workflow.csv \
  --rows-per-file 70 \
  --from-kst "$FROM" \
  --to-kst "$TO" \
  "${VENDOR_OPTION[@]}" \
  --db-host "$DB_HOST" \
  --db-port "$DB_PORT" \
  --db-user "$DB_USER" \
  --db-password "$QUERYPIE_DB_PASSWORD" \
  --db-name "$DB_NAME" \
  "${APPROVAL_RULE_OPTION[@]}" 2>&1 | tee $BASEDIR/progress_export

for INPUT_PATH in $( /bin/ls $BASEDIR/workflow.*.csv ); do
    INPUT_FILENAME=$( basename $INPUT_PATH)
    echo " == Process $INPUT_FILENAME =="
    python2.7 enrich_workflow_sql_audit.py \
        "${VENDOR_OPTION[@]}" \
        --input $BASEDIR/${INPUT_FILENAME} \
        --output $BASEDIR/result/output_${INPUT_FILENAME} \
        --workflow-column workflow_uuid \
        --log-db-host "$LOG_DB_HOST" \
        --log-db-port "$LOG_DB_PORT" \
        --log-db-user "$LOG_DB_USER" \
        --log-db-password "$LOG_DB_PASSWORD" \
        --log-db-name "$LOG_DB_NAME" \
        --app-db-host "$DB_HOST" \
        --app-db-port "$DB_PORT" \
        --app-db-user "$DB_USER" \
        --app-db-password "$QUERYPIE_DB_PASSWORD" \
        --app-db-name "$DB_NAME" \
        --snapshot-db-host "$SNAPSHOT_DB_HOST" \
        --snapshot-db-port "$SNAPSHOT_DB_PORT" \
        --snapshot-db-user "$SNAPSHOT_DB_USER" \
        --snapshot-db-password "$SNAPSHOT_DB_PASSWORD" \
        --snapshot-db-name "$SNAPSHOT_DB_NAME" \
        "${DML_SNAPSHOT_OPTION[@]}" \
        --inline-threshold-bytes 2000 \
        --large-file-mode skip 2>&1 | tee $BASEDIR/progress/progress_${INPUT_FILENAME}
done
