#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Append Query Audit SQL text and DML snapshot data to a Workflow report CSV.

Python 2.7 compatible on purpose: some customer/operation hosts still ship old
Python. The script does not call QueryPie APIs. It reads Query Audit rows from
querypie_log and reads DML snapshot blobs from the Engine snapshot database.
"""
from __future__ import print_function

import argparse
import csv
import gzip
import io
import json
import os
import sys
import traceback
from collections import defaultdict


PY2 = sys.version_info[0] == 2
QUERY_SEPARATOR = u"\n\n--- query audit ---\n\n"
SNAPSHOT_SEPARATOR = u"\n\n--- dml snapshot ---\n\n"
TOO_LARGE_MESSAGE = u"파일 사이즈가 너무 커서 CSV에 직접 넣기 어렵습니다. (%s)"
TOO_LARGE_CELL_MESSAGE = u"파일 사이즈가 너무 커서 CSV에 직접 넣기 어렵습니다. (%s)"
LARGE_FILE_SAVED_MESSAGE = u"파일 사이즈가 너무 커서 별도 파일로 저장했습니다. (%s)"


class DbConfig(object):
    def __init__(self, host, port, user, password, database, charset="utf8mb4"):
        self.host = host
        self.port = int(port)
        self.user = user
        self.password = password
        self.database = database
        self.charset = charset


class QueryAuditRow(object):
    def __init__(
        self,
        workflow_uuid,
        query_audit_uuid,
        sub_query_index,
        executed_at,
        processed_record_count,
        short_query_text,
        compressed_full_query_text,
        target_object_names_csv,
        data_changes_json,
    ):
        self.workflow_uuid = workflow_uuid
        self.query_audit_uuid = query_audit_uuid
        self.sub_query_index = sub_query_index
        self.executed_at = executed_at
        self.processed_record_count = processed_record_count
        self.short_query_text = short_query_text
        self.compressed_full_query_text = compressed_full_query_text
        self.target_object_names_csv = target_object_names_csv
        self.data_changes_json = data_changes_json


class SnapshotValue(object):
    def __init__(self, uuid, byte_count=None, content=None, message=None, file_path=None, inline_threshold=None):
        self.uuid = uuid
        self.byte_count = byte_count
        self.content = content
        self.message = message
        self.file_path = file_path
        self.inline_threshold = inline_threshold

    def render(self):
        if self.content is not None:
            return self.content
        if self.file_path:
            return LARGE_FILE_SAVED_MESSAGE % (
                self.byte_count if self.byte_count is not None else "unknown",
            )
        if self.message:
            return self.message
        return u"MISSING uuid=%s" % self.uuid


def is_text(value):
    if PY2:
        return isinstance(value, unicode)  # noqa: F821  pylint: disable=undefined-variable
    return isinstance(value, str)


def to_text(value, encoding="utf-8"):
    if value is None:
        return u""
    if is_text(value):
        return value
    if isinstance(value, bytes):
        return value.decode(encoding, "replace")
    return unicode(value) if PY2 else str(value)  # noqa: F821  pylint: disable=undefined-variable


def csv_cell_encoding(encoding):
    # utf-8-sig writes a BOM on every encode() call in Python 2. CSV cells must
    # be encoded as plain UTF-8, with the BOM written once at file start.
    return "utf-8" if encoding.lower().replace("_", "-") == "utf-8-sig" else encoding


def strip_bom(value):
    return to_text(value).lstrip(u"\ufeff")


def to_csv_cell(value, encoding):
    text = to_text(value, encoding)
    return text.encode(csv_cell_encoding(encoding)) if PY2 else text


def env_or_default(name, default=None):
    value = os.environ.get(name)
    return value if value not in (None, "") else default


def parse_args():
    parser = argparse.ArgumentParser(
        description="Enrich a Workflow CSV with Query Audit original queries and DML snapshot before/after data.",
    )
    parser.add_argument("--input", required=True, help="Input Workflow CSV path.")
    parser.add_argument("--output", required=True, help="Output enriched CSV path.")
    parser.add_argument(
        "--workflow-column",
        required=True,
        help="Workflow UUID column. Use a 1-based index such as 1, or a header name when --header is set.",
    )
    parser.add_argument("--header", dest="header", action="store_true", default=True, help="CSV has a header row. Default.")
    parser.add_argument("--no-header", dest="header", action="store_false", help="CSV has no header row.")
    parser.add_argument("--encoding", default="utf-8-sig", help="Input/output CSV encoding. Default: utf-8-sig.")

    parser.add_argument("--log-db-host", default=env_or_default("QUERYPIE_LOG_DB_HOST", "127.0.0.1"))
    parser.add_argument("--log-db-port", type=int, default=int(env_or_default("QUERYPIE_LOG_DB_PORT", "3306") or "3306"))
    parser.add_argument("--log-db-user", default=env_or_default("QUERYPIE_LOG_DB_USER", "querypie"))
    parser.add_argument("--log-db-password", default=env_or_default("QUERYPIE_LOG_DB_PASSWORD", "querypie"))
    parser.add_argument("--log-db-name", default=env_or_default("QUERYPIE_LOG_DB_NAME", "querypie_log"))

    parser.add_argument("--app-db-host", default=env_or_default("QUERYPIE_DB_HOST", env_or_default("QUERYPIE_LOG_DB_HOST", "127.0.0.1")))
    parser.add_argument("--app-db-port", type=int, default=int(env_or_default("QUERYPIE_DB_PORT", env_or_default("QUERYPIE_LOG_DB_PORT", "3306")) or "3306"))
    parser.add_argument("--app-db-user", default=env_or_default("QUERYPIE_DB_USER", env_or_default("QUERYPIE_LOG_DB_USER", "querypie")))
    parser.add_argument("--app-db-password", default=env_or_default("QUERYPIE_DB_PASSWORD", env_or_default("QUERYPIE_LOG_DB_PASSWORD", "querypie")))
    parser.add_argument("--app-db-name", default=env_or_default("QUERYPIE_DB_NAME", "querypie"))

    parser.add_argument("--snapshot-db-host", default=env_or_default("QUERYPIE_SNAPSHOT_DB_HOST"))
    parser.add_argument("--snapshot-db-port", type=int, default=None)
    parser.add_argument("--snapshot-db-user", default=env_or_default("QUERYPIE_SNAPSHOT_DB_USER"))
    parser.add_argument("--snapshot-db-password", default=env_or_default("QUERYPIE_SNAPSHOT_DB_PASSWORD"))
    parser.add_argument("--snapshot-db-name", default=env_or_default("QUERYPIE_SNAPSHOT_DB_NAME", "querypie_snapshot"))

    parser.add_argument(
        "--inline-threshold-bytes",
        type=int,
        default=10000,
        help="Max snapshot size to inline in the output CSV. Larger snapshots are written to files by default. Default: 10000.",
    )
    parser.add_argument(
        "--large-file-mode",
        choices=("skip", "file"),
        default="file",
        help="For snapshots larger than the threshold: 'file' downloads to --snapshot-output-dir, 'skip' writes a too-large message. Default: file.",
    )
    parser.add_argument(
        "--snapshot-output-dir",
        default=None,
        help="Directory for large snapshot files when --large-file-mode=file. Default: <output>.snapshots.",
    )
    parser.add_argument("--batch-size", type=int, default=500, help="Workflow UUID batch size for Query Audit lookup. Default: 500.")
    parser.add_argument(
        "--include-workflow-uuid",
        action="store_true",
        help="Keep the workflow UUID column in the output CSV. By default it is used for lookup only and removed from output.",
    )
    parser.add_argument("--include-query-audit-index", action="store_true", help="Output the query_audit_index column.")
    parser.add_argument("--include-query-audit-uuid", action="store_true", help="Output the query_audit_uuid column.")
    parser.add_argument("--include-dml-snapshot-refs", action="store_true", help="Output the dml_snapshot_refs column.")
    parser.add_argument(
        "--include-dml-snapshots",
        action="store_true",
        help="Fetch and output DML snapshot before/after data. Disabled by default.",
    )
    parser.add_argument(
        "--include-internal-columns",
        action="store_true",
        help="Shortcut for --include-workflow-uuid, --include-query-audit-index, --include-query-audit-uuid, and --include-dml-snapshot-refs.",
    )
    parser.add_argument(
        "--vendor-dir",
        default=env_or_default("QUERYPIE_AUDIT_VENDOR_DIR"),
        help="Directory containing pre-downloaded Python packages, for closed-network hosts. Also configurable with QUERYPIE_AUDIT_VENDOR_DIR.",
    )
    args = parser.parse_args()
    if args.batch_size <= 0:
        raise SystemExit("--batch-size must be greater than 0.")
    if args.inline_threshold_bytes <= 0:
        raise SystemExit("--inline-threshold-bytes must be greater than 0.")
    if args.large_file_mode == "file" and not args.snapshot_output_dir:
        args.snapshot_output_dir = args.output + ".snapshots"
    return args


def add_vendor_dir(vendor_dir):
    if not vendor_dir:
        return
    if not os.path.isdir(vendor_dir):
        raise SystemExit("Vendor directory does not exist: %s" % vendor_dir)
    abs_vendor_dir = os.path.abspath(vendor_dir)
    if abs_vendor_dir not in sys.path:
        sys.path.insert(0, abs_vendor_dir)


def connect(config):
    try:
        import pymysql

        return pymysql.connect(
            host=config.host,
            port=config.port,
            user=config.user,
            password=config.password,
            database=config.database,
            charset=config.charset,
            cursorclass=pymysql.cursors.DictCursor,
            autocommit=True,
        )
    except ImportError:
        try:
            import mysql.connector
        except ImportError:
            raise SystemExit("Install PyMySQL or mysql-connector-python to use this script.")

        return mysql.connector.connect(
            host=config.host,
            port=config.port,
            user=config.user,
            password=config.password,
            database=config.database,
            charset=config.charset,
        )


def cursor_for(conn):
    module = conn.__class__.__module__
    if module.startswith("mysql.connector"):
        return conn.cursor(dictionary=True)
    return conn.cursor()


def dict_rows(cursor):
    rows = cursor.fetchall()
    if not rows:
        return []
    first = rows[0]
    if isinstance(first, dict):
        return rows
    columns = [desc[0] for desc in cursor.description]
    return [dict(zip(columns, row)) for row in rows]


def chunks(values, size):
    start = 0
    while start < len(values):
        yield values[start : start + size]
        start += size


def placeholders(count):
    return ",".join(["%s"] * count)


def read_csv(path, has_header, encoding):
    if PY2:
        fp = open(path, "rb")
        try:
            reader = csv.reader(fp)
            all_rows = [[strip_bom(to_text(cell, csv_cell_encoding(encoding))) for cell in row] for row in reader]
        finally:
            fp.close()
    else:
        with open(path, "r", newline="", encoding=encoding) as fp:
            all_rows = [[strip_bom(cell) for cell in row] for row in csv.reader(fp)]
    if has_header and all_rows:
        return all_rows[0], all_rows[1:]
    return None, all_rows


def write_csv(path, header, rows, encoding):
    parent = os.path.dirname(os.path.abspath(path))
    if parent and not os.path.exists(parent):
        os.makedirs(parent)

    if PY2:
        fp = open(path, "wb")
        try:
            if encoding.lower().replace("_", "-") == "utf-8-sig":
                fp.write(u"\ufeff".encode("utf-8"))
            writer = csv.writer(fp)
            if header is not None:
                writer.writerow([to_csv_cell(cell, encoding) for cell in header])
            for row in rows:
                writer.writerow([to_csv_cell(cell, encoding) for cell in row])
        finally:
            fp.close()
    else:
        with open(path, "w", newline="", encoding=encoding) as fp:
            writer = csv.writer(fp)
            if header is not None:
                writer.writerow(header)
            writer.writerows(rows)


def open_csv_writer(path, encoding):
    parent = os.path.dirname(os.path.abspath(path))
    if parent and not os.path.exists(parent):
        os.makedirs(parent)

    if PY2:
        fp = open(path, "wb")
        if encoding.lower().replace("_", "-") == "utf-8-sig":
            fp.write(u"\ufeff".encode("utf-8"))
        return fp, csv.writer(fp)

    fp = open(path, "w", newline="", encoding=encoding)
    return fp, csv.writer(fp)


def write_csv_row(writer, row, encoding):
    writer.writerow([to_csv_cell(cell, encoding) for cell in row])


def normalize_uuid(value):
    return to_text(value).strip().strip('"').strip("'")


def parse_connection_database(value):
    text = to_text(value).strip()
    if u" / " in text:
        connection_name, database_name = text.rsplit(u" / ", 1)
        return connection_name.strip(), database_name.strip()
    return text, u""


def normalize_identifier(value):
    text = to_text(value).strip()
    while len(text) >= 2 and (
        (text[0] == "`" and text[-1] == "`")
        or (text[0] == '"' and text[-1] == '"')
        or (text[0] == "'" and text[-1] == "'")
        or (text[0] == "[" and text[-1] == "]")
    ):
        text = text[1:-1].strip()
    return text.lower()


def normalize_ledger_key(connection_name, database_name, schema_name, table_name):
    return (
        normalize_identifier(connection_name),
        normalize_identifier(database_name),
        normalize_identifier(schema_name),
        normalize_identifier(table_name),
    )


def parse_query_table(value, fallback_database_name):
    original = to_text(value).strip()
    parts = [normalize_identifier(part) for part in original.split(".") if to_text(part).strip()]
    if len(parts) >= 3:
        return original, parts[0], parts[-2], parts[-1]
    if len(parts) == 2:
        return original, parts[0], u"", parts[1]
    if len(parts) == 1:
        return original, normalize_identifier(fallback_database_name), u"", parts[0]
    return original, u"", u"", u""


def render_table_name(database_name, schema_name, table_name):
    return u".".join([value for value in (to_text(database_name).strip(), to_text(schema_name).strip(), to_text(table_name).strip()) if value])


def read_ledger_targets(conn):
    sql = """
        SELECT DISTINCT
            cg.name AS connection_name,
            lp.database_name AS database_name,
            lpt.schema_name AS schema_name,
            lpt.table_name AS table_name,
            DATE_FORMAT(DATE_ADD(lpt.created_at, INTERVAL 9 HOUR), '%%Y-%%m-%%d %%H:%%i:%%s') AS ledger_table_created_at,
            DATE_FORMAT(DATE_ADD(lpt.updated_at, INTERVAL 9 HOUR), '%%Y-%%m-%%d %%H:%%i:%%s') AS ledger_table_updated_at
        FROM ledger_policy_tables lpt
        INNER JOIN policies p ON p.uuid = lpt.policy_uuid
        INNER JOIN ledger_policies lp ON lp.policy_uuid = p.uuid
        INNER JOIN workflow_rules ledger_rule ON ledger_rule.uuid = lpt.workflow_rule_uuid
        INNER JOIN cluster_groups cg ON cg.uuid = p.object_uuid
        WHERE p.object_type = 'CLUSTER_GROUP'
          AND p.type = 'LEDGER'
          AND p.deleted = 0
          AND lp.deleted = 0
          AND lpt.deleted = 0
          AND ledger_rule.deleted = 0
          AND ledger_rule.name = 'Ledger Rule'
          AND cg.deleted = 0
          AND cg.name IS NOT NULL AND cg.name <> ''
          AND lp.database_name IS NOT NULL AND lp.database_name <> ''
          AND lpt.table_name IS NOT NULL AND lpt.table_name <> ''
        ORDER BY cg.name, lp.database_name, lpt.schema_name, lpt.table_name
    """
    exact_keys = set()
    by_connection_database_table = defaultdict(list)
    display_by_key = {}
    created_at_by_key = {}
    updated_at_by_key = {}
    cursor = cursor_for(conn)
    try:
        cursor.execute(sql)
        for row in dict_rows(cursor):
            key = normalize_ledger_key(row.get("connection_name"), row.get("database_name"), row.get("schema_name"), row.get("table_name"))
            exact_keys.add(key)
            by_connection_database_table[(key[0], key[1], key[3])].append(key)
            display_by_key[key] = render_table_name(row.get("database_name"), row.get("schema_name"), row.get("table_name"))
            created_at_by_key[key] = to_text(row.get("ledger_table_created_at"))
            updated_at_by_key[key] = to_text(row.get("ledger_table_updated_at"))
    finally:
        cursor.close()
    return exact_keys, by_connection_database_table, display_by_key, created_at_by_key, updated_at_by_key


def find_ledger_match(connection_name, database_name, schema_name, table_name, ledger_data):
    exact_keys, by_connection_database_table, display_by_key, created_at_by_key, updated_at_by_key = ledger_data
    key = normalize_ledger_key(connection_name, database_name, schema_name, table_name)
    candidates = [key] if key in exact_keys else by_connection_database_table.get((key[0], key[1], key[3]), [])
    if not candidates:
        return False, u"", u"", u""
    if key[2]:
        candidates = [candidate for candidate in candidates if candidate[2] == key[2]]
        if not candidates:
            return False, u"", u"", u""
    return (
        True,
        u", ".join([display_by_key.get(candidate, u"") for candidate in candidates]),
        u", ".join([created_at_by_key.get(candidate, u"") for candidate in candidates]),
        u", ".join([updated_at_by_key.get(candidate, u"") for candidate in candidates]),
    )


def resolve_workflow_column(rows, header, column):
    if column.isdigit():
        index = int(column) - 1
    elif header is not None:
        try:
            index = header.index(column)
        except ValueError:
            raise SystemExit("Workflow column header not found: %s" % column)
    else:
        raise SystemExit("--workflow-column must be a 1-based index when --no-header is used.")

    width = len(header) if header is not None else (len(rows[0]) if rows else 0)
    if index < 0 or index >= width:
        raise SystemExit("Workflow column index out of range: %s" % column)
    return index


def read_query_audits(conn, workflow_uuids, batch_size):
    result = defaultdict(list)
    sql_template = """
        SELECT
            l.query_request_uuid AS workflow_uuid,
            l.uuid AS query_audit_uuid,
            l.query_request_sub_query_index AS sub_query_index,
            DATE_FORMAT(DATE_ADD(l.executed_at, INTERVAL 9 HOUR), '%%Y-%%m-%%d %%H:%%i:%%s') AS executed_at,
            l.processed_record_count AS processed_record_count,
            l.query_text AS short_query_text,
            d.full_query_text AS compressed_full_query_text,
            d.target_object_names AS target_object_names_csv,
            d.data_changes AS data_changes_json
        FROM l_query_execution_logs l
        LEFT JOIN l_query_execution_log_details d ON d.id = l.id
        WHERE l.query_request_uuid IN ({ids})
          AND l.hidden = 0
        ORDER BY l.query_request_uuid, l.query_request_sub_query_index, l.executed_at, l.id
    """
    cursor = cursor_for(conn)
    try:
        for batch in chunks(workflow_uuids, batch_size):
            cursor.execute(sql_template.format(ids=placeholders(len(batch))), batch)
            for row in dict_rows(cursor):
                audit = QueryAuditRow(
                    workflow_uuid=to_text(row.get("workflow_uuid")),
                    query_audit_uuid=to_text(row.get("query_audit_uuid")),
                    sub_query_index=row.get("sub_query_index"),
                    executed_at=row.get("executed_at"),
                    processed_record_count=row.get("processed_record_count"),
                    short_query_text=to_text(row.get("short_query_text")) if row.get("short_query_text") is not None else None,
                    compressed_full_query_text=row.get("compressed_full_query_text"),
                    target_object_names_csv=to_text(row.get("target_object_names_csv")) if row.get("target_object_names_csv") is not None else None,
                    data_changes_json=to_text(row.get("data_changes_json")) if row.get("data_changes_json") is not None else None,
                )
                result[audit.workflow_uuid].append(audit)
    finally:
        cursor.close()
    return result


def row_batches(rows, workflow_col_index, batch_size):
    batch = []
    workflow_uuids = set()
    for row in rows:
        batch.append(row)
        workflow_uuid = normalize_uuid(row[workflow_col_index]) if len(row) > workflow_col_index else u""
        if workflow_uuid:
            workflow_uuids.add(workflow_uuid)
        if len(workflow_uuids) >= batch_size:
            yield batch
            batch = []
            workflow_uuids = set()
    if batch:
        yield batch


def decode_query_text(compressed_full_query_text, short_query_text):
    if compressed_full_query_text:
        raw = bytes(compressed_full_query_text) if not PY2 else compressed_full_query_text
        try:
            return gzip.GzipFile(fileobj=io.BytesIO(raw)).read().decode("utf-8", "replace")
        except Exception:
            try:
                return raw.decode("utf-8", "replace") if not PY2 else raw.decode("utf-8", "replace")
            except Exception:
                pass
    return short_query_text or u""


def parse_data_changes(value):
    if not value:
        return []
    try:
        parsed = json.loads(value)
    except ValueError:
        return []
    if isinstance(parsed, list):
        return [item for item in parsed if isinstance(item, dict)]
    return []


def parse_target_object_names(value):
    names = []
    for item in to_text(value).split(","):
        append_unique(names, item)
    return names


def collect_snapshot_uuids(audits_by_workflow):
    snapshot_uuids = set()
    for audits in audits_by_workflow.values():
        for audit in audits:
            for change in parse_data_changes(audit.data_changes_json):
                for key in ("oldDataSnapshotUuid", "newDataSnapshotUuid"):
                    value = change.get(key)
                    if is_text(value) and value.strip():
                        snapshot_uuids.add(value.strip())
    return snapshot_uuids


def read_blob_meta(conn, snapshot_uuids, batch_size):
    if not snapshot_uuids:
        return {}
    result = {}
    names = sorted(snapshot_uuids)
    sql_template = "SELECT name, bytes FROM blob_meta WHERE name IN ({ids})"
    cursor = cursor_for(conn)
    try:
        for batch in chunks(names, batch_size):
            cursor.execute(sql_template.format(ids=placeholders(len(batch))), batch)
            for row in dict_rows(cursor):
                result[to_text(row.get("name"))] = row.get("bytes")
    finally:
        cursor.close()
    return result


def read_blob_content(conn, name):
    cursor = cursor_for(conn)
    try:
        cursor.execute("SELECT data FROM blobs WHERE name=%s ORDER BY idx", (name,))
        parts = []
        for row in dict_rows(cursor):
            data = row.get("data")
            if data is not None:
                parts.append(bytes(data) if not PY2 else data)
        if not parts:
            return None
        return b"".join(parts).decode("utf-8", "replace")
    finally:
        cursor.close()


def materialize_snapshot(conn, name, blob_meta, threshold, large_file_mode, output_dir):
    byte_count = blob_meta.get(name)
    if name not in blob_meta:
        return SnapshotValue(uuid=name, message=u"MISSING uuid=%s" % name)

    if byte_count is not None and int(byte_count) >= threshold:
        if large_file_mode == "file":
            if output_dir is None:
                raise SystemExit("--snapshot-output-dir is required when --large-file-mode=file")
            content = read_blob_content(conn, name)
            if content is None:
                return SnapshotValue(uuid=name, byte_count=byte_count, message=u"MISSING uuid=%s bytes=%s" % (name, byte_count))
            if not os.path.exists(output_dir):
                os.makedirs(output_dir)
            file_name = name.replace("/", "_")
            if not file_name.lower().endswith(".csv"):
                file_name += ".csv"
            path = os.path.join(output_dir, file_name)
            fp = io.open(path, "w", encoding="utf-8")
            try:
                fp.write(content)
            finally:
                fp.close()
            return SnapshotValue(uuid=name, byte_count=byte_count, file_path=path, inline_threshold=threshold)

        print("TOO_LARGE_MESSAGE: %s" % (byte_count), file=sys.stderr)
        return SnapshotValue(
            uuid=name,
            byte_count=byte_count,
            message=TOO_LARGE_MESSAGE % (byte_count),
        )

    content = read_blob_content(conn, name)
    return SnapshotValue(uuid=name, byte_count=byte_count, content=content)


def materialize_snapshot_cached(conn, name, blob_meta, threshold, large_file_mode, output_dir, cache):
    if not name:
        return None
    if name not in cache:
        cache[name] = materialize_snapshot(conn, name, blob_meta, threshold, large_file_mode, output_dir)
    return cache[name]


def byte_len(value):
    return len(to_text(value).encode("utf-8"))


def render_snapshot_values(values, threshold):
    rendered_values = [value.render() for value in values if value is not None]
    rendered = SNAPSHOT_SEPARATOR.join(rendered_values)
    if rendered and byte_len(rendered) >= threshold:
        return TOO_LARGE_CELL_MESSAGE % (byte_len(rendered))
    return rendered


def render_snapshot_side(snapshot_conn, snapshot_names, blob_meta, threshold, large_file_mode, output_dir):
    rendered = []
    for name in snapshot_names:
        value = materialize_snapshot(snapshot_conn, name, blob_meta, threshold, large_file_mode, output_dir)
        rendered.append(value.render())
    return SNAPSHOT_SEPARATOR.join(rendered)


def append_unique(values, value):
    text = to_text(value).strip()
    if text and text not in values:
        values.append(text)


def parse_snapshot_csv(content):
    if content is None:
        return [], []
    if PY2:
        fp = io.BytesIO(to_text(content).encode("utf-8"))
        reader = csv.reader(fp)
        rows = [[strip_bom(to_text(cell, "utf-8")) for cell in row] for row in reader]
    else:
        fp = io.StringIO(to_text(content))
        rows = [[strip_bom(cell) for cell in row] for row in csv.reader(fp)]

    rows = [row for row in rows if any(to_text(cell).strip() for cell in row)]
    if not rows:
        return [], []
    return rows[0], rows[1:]


def try_parse_json(value):
    text = to_text(value).strip()
    if not text:
        return None
    if not (text.startswith("{") or text.startswith("[")):
        return None
    try:
        return json.loads(text)
    except ValueError:
        return None


def flatten_json_paths(value, prefix=u""):
    result = {}
    if isinstance(value, dict):
        for key in sorted(value.keys()):
            path = u"%s.%s" % (prefix, to_text(key)) if prefix else to_text(key)
            result.update(flatten_json_paths(value.get(key), path))
        return result
    if isinstance(value, list):
        for index, item in enumerate(value):
            path = u"%s[%s]" % (prefix, index) if prefix else u"[%s]" % index
            result.update(flatten_json_paths(item, path))
        if not value and prefix:
            result[prefix] = u"[]"
        return result
    result[prefix or u"$"] = json.dumps(value, ensure_ascii=False, sort_keys=True)
    return result


def extract_json_documents_from_snapshot(snapshot_value):
    if snapshot_value is None or snapshot_value.content is None:
        return None

    header, rows = parse_snapshot_csv(snapshot_value.content)
    documents = []
    for row in rows:
        parsed = None
        joined_row = u",".join([to_text(cell) for cell in row]).strip()
        if len(row) > 1 and (joined_row.startswith("{") or joined_row.startswith("[")):
            parsed = try_parse_json(joined_row)
        if len(row) == 1:
            parsed = try_parse_json(row[0])
        if parsed is None:
            for index, cell in enumerate(row):
                column_name = header[index].lower() if index < len(header) else u""
                if column_name in ("document", "documents", "value", "json", "data", "row") or try_parse_json(cell) is not None:
                    parsed = try_parse_json(cell)
                    if parsed is not None:
                        break
        if parsed is None:
            return None
        documents.append(parsed)
    return documents


def snapshot_row_count(snapshot_value):
    if snapshot_value is None or snapshot_value.content is None:
        return None
    _, rows = parse_snapshot_csv(snapshot_value.content)
    return len(rows)


def snapshot_header_columns(snapshot_value):
    if snapshot_value is None or snapshot_value.content is None:
        return []
    header, _ = parse_snapshot_csv(snapshot_value.content)
    columns = []
    for column in header:
        append_unique(columns, column)
    return columns


def snapshot_non_empty_columns(snapshot_value, sample_size=3):
    if snapshot_value is None or snapshot_value.content is None:
        return []
    header, rows = parse_snapshot_csv(snapshot_value.content)
    columns = []
    for row in rows[:sample_size]:
        for index, cell in enumerate(row):
            if not to_text(cell).strip():
                continue
            column_name = header[index] if index < len(header) and header[index] else u"column_%s" % (index + 1)
            append_unique(columns, column_name)
    return columns


def is_document_like_columns(columns):
    if not columns:
        return False
    normalized = [to_text(column).strip().lower() for column in columns]
    if len(normalized) == 1 and normalized[0] in ("document", "documents", "value", "json", "data", "row"):
        return True
    return False


def changed_json_paths_from_snapshots(before_value, after_value):
    before_documents = extract_json_documents_from_snapshot(before_value)
    after_documents = extract_json_documents_from_snapshot(after_value)
    if before_documents is None or after_documents is None:
        return []

    max_rows = max(len(before_documents), len(after_documents))
    changed = []
    for row_index in range(max_rows):
        before_flat = flatten_json_paths(before_documents[row_index]) if row_index < len(before_documents) else {}
        after_flat = flatten_json_paths(after_documents[row_index]) if row_index < len(after_documents) else {}
        for path in sorted(set(before_flat.keys()) | set(after_flat.keys())):
            if before_flat.get(path) != after_flat.get(path):
                append_unique(changed, path)
    return changed


def changed_columns_from_snapshots(before_value, after_value):
    if (
        before_value is None
        or after_value is None
        or before_value.content is None
        or after_value.content is None
    ):
        return []

    before_header, before_rows = parse_snapshot_csv(before_value.content)
    after_header, after_rows = parse_snapshot_csv(after_value.content)
    header_columns = []
    for column in before_header + after_header:
        append_unique(header_columns, column)

    if is_document_like_columns(header_columns):
        return []

    if not before_header and not after_header:
        return []

    max_columns = max(len(before_header), len(after_header))
    max_rows = max(len(before_rows), len(after_rows))
    changed = []
    for column_index in range(max_columns):
        column_name = (
            before_header[column_index]
            if column_index < len(before_header) and before_header[column_index]
            else (after_header[column_index] if column_index < len(after_header) else u"column_%s" % (column_index + 1))
        )
        different = False
        for row_index in range(max_rows):
            before_cell = (
                before_rows[row_index][column_index]
                if row_index < len(before_rows) and column_index < len(before_rows[row_index])
                else u""
            )
            after_cell = (
                after_rows[row_index][column_index]
                if row_index < len(after_rows) and column_index < len(after_rows[row_index])
                else u""
            )
            if before_cell != after_cell:
                different = True
                break
        if different:
            append_unique(changed, column_name)
    return changed


def format_scoped_values(items):
    cleaned = [(to_text(scope).strip(), to_text(value).strip()) for scope, value in items if to_text(value).strip()]
    if not cleaned:
        return u""
    scopes = [scope for scope, _ in cleaned if scope]
    if len(cleaned) == 1:
        return cleaned[0][1]
    if scopes and len(set(scopes)) == len(cleaned):
        return u", ".join([u"%s: %s" % (scope, value) for scope, value in cleaned])
    values = []
    for _, value in cleaned:
        append_unique(values, value)
    return u", ".join(values)


def build_blank_enrichment():
    return [u""] * len(ENRICHMENT_KEYS)


def build_error_enrichment(audit, audit_index, message):
    try:
        query_text = decode_query_text(audit.compressed_full_query_text, audit.short_query_text)
    except Exception:
        query_text = audit.short_query_text or u""
    return [
        to_text(audit_index),
        to_text(audit.sub_query_index) if audit.sub_query_index is not None else u"",
        audit.query_audit_uuid,
        to_text(audit.executed_at),
        query_text,
        to_text(audit.target_object_names_csv) if audit.target_object_names_csv is not None else u"",
        u"",
        to_text(audit.processed_record_count) if audit.processed_record_count is not None else u"",
        message,
        message,
        u"",
        u"",
        u"",
        u"",
        u"",
    ]


def log_audit_processing_error(workflow_uuid, audit, audit_index):
    print(
        "ERROR while enriching DML snapshot: workflow_uuid=%s query_audit_uuid=%s query_index=%s sub_query_index=%s"
        % (
            workflow_uuid,
            audit.query_audit_uuid,
            audit_index,
            audit.sub_query_index if audit.sub_query_index is not None else "",
        ),
        file=sys.stderr,
    )
    traceback.print_exc(file=sys.stderr)


def build_enrichment_for_audit(
    audit,
    audit_index,
    snapshot_conn,
    blob_meta,
    threshold,
    large_file_mode,
    output_dir,
    connection_database,
    ledger_data,
    include_dml_snapshots,
):
    query_text = decode_query_text(audit.compressed_full_query_text, audit.short_query_text)
    before_values = []
    after_values = []
    target_objects = parse_target_object_names(audit.target_object_names_csv)
    scoped_columns = []
    scoped_row_counts = []
    change_summaries = []
    ledger_matches = []
    matched_ledger_tables = []
    ledger_table_created_ats = []
    ledger_table_updated_ats = []
    snapshot_cache = {}
    connection_name, fallback_database_name = parse_connection_database(connection_database)
    for change in parse_data_changes(audit.data_changes_json):
        old_uuid = change.get("oldDataSnapshotUuid")
        new_uuid = change.get("newDataSnapshotUuid")
        target_object = to_text(change.get("targetObject")).strip()
        if not target_objects:
            append_unique(target_objects, target_object)
        before_value = None
        after_value = None
        if include_dml_snapshots and is_text(old_uuid) and old_uuid.strip():
            before_value = materialize_snapshot_cached(
                snapshot_conn,
                old_uuid.strip(),
                blob_meta,
                threshold,
                large_file_mode,
                output_dir,
                snapshot_cache,
            )
            before_values.append(before_value)
        if include_dml_snapshots and is_text(new_uuid) and new_uuid.strip():
            after_value = materialize_snapshot_cached(
                snapshot_conn,
                new_uuid.strip(),
                blob_meta,
                threshold,
                large_file_mode,
                output_dir,
                snapshot_cache,
            )
            after_values.append(after_value)

        changed_columns = []
        if include_dml_snapshots and before_value is not None and after_value is not None:
            for column in snapshot_non_empty_columns(before_value) + snapshot_non_empty_columns(after_value):
                append_unique(changed_columns, column)
            if is_document_like_columns(changed_columns):
                changed_columns = []
            elif not changed_columns:
                fallback_columns = []
                for column in snapshot_header_columns(before_value) + snapshot_header_columns(after_value):
                    append_unique(fallback_columns, column)
                if is_document_like_columns(fallback_columns):
                    changed_columns = []
                else:
                    changed_columns = changed_columns_from_snapshots(before_value, after_value)
        if changed_columns:
            scoped_columns.append((target_object, u", ".join(changed_columns)))

        if include_dml_snapshots and audit.processed_record_count is None:
            before_count = snapshot_row_count(before_value)
            after_count = snapshot_row_count(after_value)
            row_counts = [count for count in (before_count, after_count) if count is not None]
            if row_counts:
                scoped_row_counts.append((target_object, to_text(max(row_counts))))

        change_summaries.append(
            json.dumps(
                {
                    "queryAuditUuid": audit.query_audit_uuid,
                    "type": change.get("type"),
                    "targetObject": change.get("targetObject"),
                    "oldDataSnapshotUuid": old_uuid,
                    "newDataSnapshotUuid": new_uuid,
                },
                ensure_ascii=False,
            ),
        )

    before = render_snapshot_values(before_values, threshold)
    after = render_snapshot_values(after_values, threshold)
    for target_object in target_objects:
        _, database_name, schema_name, table_name = parse_query_table(target_object, fallback_database_name)
        is_ledger, matched_table, created_at, updated_at = find_ledger_match(
            connection_name,
            database_name,
            schema_name,
            table_name,
            ledger_data,
        )
        ledger_matches.append((target_object, u"Y" if is_ledger else u"N"))
        if is_ledger:
            matched_ledger_tables.append((target_object, matched_table))
            ledger_table_created_ats.append((target_object, created_at))
            ledger_table_updated_ats.append((target_object, updated_at))
    return [
        to_text(audit_index),
        to_text(audit.sub_query_index) if audit.sub_query_index is not None else u"",
        audit.query_audit_uuid,
        to_text(audit.executed_at),
        query_text,
        u", ".join(target_objects),
        format_scoped_values(scoped_columns),
        to_text(audit.processed_record_count) if audit.processed_record_count is not None else format_scoped_values(scoped_row_counts),
        before,
        after,
        SNAPSHOT_SEPARATOR.join([to_text(item) for item in change_summaries]),
        format_scoped_values(ledger_matches),
        format_scoped_values(matched_ledger_tables),
        format_scoped_values(ledger_table_created_ats),
        format_scoped_values(ledger_table_updated_ats),
    ]


ENRICHMENT_KEYS = [
    "query_audit_index",
    "query_request_sub_query_index",
    "query_audit_uuid",
    "executed_at",
    "query_original",
    "target_object",
    "changed_columns",
    "affected_row_count",
    "dml_snapshot_before",
    "dml_snapshot_after",
    "dml_snapshot_refs",
    "is_ledger_table",
    "matched_ledger_table",
    "ledger_table_created_at",
    "ledger_table_updated_at",
]


FINAL_COLUMN_SPECS = [
    (u"workflow 상신일", "base", [u"workflow 상신일", u"상신일", u"requested_at"]),
    (u"사후결제여부", "base", [u"사후결제여부", u"urgent"]),
    (u"변경수행일", "base", [u"변경수행일", u"요청 시간", u"requested_at"]),
    (u"요청자", "base", [u"요청자", u"변경요청자"]),
    (u"변경제목", "base", [u"변경제목", u"변경 제목"]),
    (u"변경사유", "base", [u"변경사유", u"사유"]),
    (u"Connection/DB명", "base", [u"Connection/DB명", u"DB명 (Connection/DB)", u"DB명", u"Connection / Database"]),
    (u"테이블명", "extra", "target_object"),
    (u"Ledger 테이블 여부", "extra", "is_ledger_table"),
    (u"매칭 Ledger 테이블", "extra", "matched_ledger_table"),
    (u"Ledger 테이블 등록일", "extra", "ledger_table_created_at"),
    (u"Ledger 테이블 수정일", "extra", "ledger_table_updated_at"),
    (u"컬럼명", "extra", "changed_columns"),
    (u"대상건수", "extra", "affected_row_count"),
    (u"쿼리실행시간", "extra", "executed_at"),
    (u"수행쿼리", "extra", "query_original"),
    (u"수행자", "base", [u"수행자"]),
    (u"1차승인자", "base", [u"1차승인자", u"책임자(1차 결제자)", u"책임자 (1차결제자)", u"책임자 (1차 결제자)", u"결재 라인 1"]),
    (u"1차승인일시", "base", [u"1차승인일시", u"결재 라인 1 승인일시"]),
    (u"2차승인자", "base", [u"2차승인자", u"제3자확인 (2차결제자)", u"제3자확인 (2차 결제자)", u"결재 라인 2"]),
    (u"2차승인일시", "base", [u"2차승인일시", u"결재 라인 2 승인일시"]),
    (u"3차승인자", "base", [u"3차승인자", u"결재 라인 3"]),
    (u"3차승인일시", "base", [u"3차승인일시", u"결재 라인 3 승인일시"]),
    (u"4차승인자", "base", [u"4차승인자", u"결재 라인 4"]),
    (u"4차승인일시", "base", [u"4차승인일시", u"결재 라인 4 승인일시"]),
    (u"변경요청근거(관리툴링크)", "base", [u"변경요청근거(관리툴링크)", u"변경요청 근거 (관리툴 링크)"]),
    (u"Workflow Ledger 여부", "base", [u"Workflow Ledger 여부", u"workflow_ledger"]),
    (u"결제선 Ledger 여부", "base", [u"결제선 Ledger 여부", u"approval_rule_ledger"]),
    (u"Ledger", "base", [u"rule_name"]),
    (u"workflow_uuid", "base", [u"workflow_uuid"]),
    (u"workflow_id", "base", [u"workflow_id", u"id"]),
]


def normalize_header_name(value):
    return to_text(value).replace(u" ", u"").strip().lower()


def build_header_index(header):
    result = {}
    if header is None:
        return result
    for index, name in enumerate(header):
        normalized = normalize_header_name(name)
        if normalized and normalized not in result:
            result[normalized] = index
    return result


def get_base_value(row, header_index, aliases):
    for alias in aliases:
        index = header_index.get(normalize_header_name(alias))
        if index is not None and index < len(row):
            return row[index]
    return u""


def enrichment_to_dict(values):
    result = {}
    for index, key in enumerate(ENRICHMENT_KEYS):
        result[key] = values[index] if index < len(values) else u""
    return result


def selected_internal_columns(args):
    columns = []
    if args.include_internal_columns or args.include_workflow_uuid:
        columns.append(("workflow_uuid", u"workflow_uuid"))
    if args.include_internal_columns or args.include_query_audit_index:
        columns.append(("query_audit_index", u"query_audit_index"))
    if args.include_internal_columns or args.include_query_audit_uuid:
        columns.append(("query_audit_uuid", u"query_audit_uuid"))
    if args.include_internal_columns or args.include_dml_snapshot_refs:
        columns.append(("dml_snapshot_refs", u"dml_snapshot_refs"))
    return columns


def final_column_specs(include_dml_snapshots):
    specs = list(FINAL_COLUMN_SPECS)
    if include_dml_snapshots:
        insert_at = 4
        specs[insert_at:insert_at] = [
            (u"변경전데이터", "extra", "dml_snapshot_before"),
            (u"변경후데이터", "extra", "dml_snapshot_after"),
        ]
    return specs


def build_final_row(row, header_index, enrichment_values, internal_columns, workflow_uuid, column_specs):
    enrichment = enrichment_to_dict(enrichment_values)
    output = []
    for _, source, selector in column_specs:
        if source == "base":
            output.append(get_base_value(row, header_index, selector))
        else:
            output.append(enrichment.get(selector, u""))

    for key, _ in internal_columns:
        if key == "workflow_uuid":
            output.append(workflow_uuid)
        else:
            output.append(enrichment.get(key, u""))
    return output


def final_output_header(internal_columns, column_specs):
    headers = [header for header, _, _ in column_specs]
    headers.extend([header for _, header in internal_columns])
    return headers


def main():
    args = parse_args()
    add_vendor_dir(args.vendor_dir)

    header, rows = read_csv(args.input, args.header, args.encoding)
    if header is None:
        raise SystemExit("--header is required for final audit column mapping.")
    workflow_col_index = resolve_workflow_column(rows, header, args.workflow_column)
    header_index = build_header_index(header)

    workflow_uuids = sorted(
        set(
            normalize_uuid(row[workflow_col_index])
            for row in rows
            if len(row) > workflow_col_index and normalize_uuid(row[workflow_col_index])
        ),
    )

    log_db = DbConfig(
        host=args.log_db_host,
        port=args.log_db_port,
        user=args.log_db_user,
        password=args.log_db_password,
        database=args.log_db_name,
    )
    snapshot_db = DbConfig(
        host=args.snapshot_db_host or args.log_db_host,
        port=args.snapshot_db_port or args.log_db_port,
        user=args.snapshot_db_user or args.log_db_user,
        password=args.snapshot_db_password if args.snapshot_db_password is not None else args.log_db_password,
        database=args.snapshot_db_name,
    )
    app_db = DbConfig(
        host=args.app_db_host,
        port=args.app_db_port,
        user=args.app_db_user,
        password=args.app_db_password,
        database=args.app_db_name,
    )

    log_conn = connect(log_db)
    snapshot_conn = connect(snapshot_db) if args.include_dml_snapshots else None
    app_conn = connect(app_db)
    output_fp = None
    try:
        ledger_data = read_ledger_targets(app_conn)
        internal_columns = selected_internal_columns(args)
        column_specs = final_column_specs(args.include_dml_snapshots)
        output_header = final_output_header(internal_columns, column_specs)

        output_fp, output_writer = open_csv_writer(args.output, args.encoding)
        write_csv_row(output_writer, output_header, args.encoding)

        found_audits = 0
        snapshot_uuid_count = 0
        output_row_count = 0
        for row_batch in row_batches(rows, workflow_col_index, args.batch_size):
            print("Gathering...", file=sys.stderr)
            batch_workflow_uuids = sorted(
                set(
                    normalize_uuid(row[workflow_col_index])
                    for row in row_batch
                    if len(row) > workflow_col_index and normalize_uuid(row[workflow_col_index])
                ),
            )
            if batch_workflow_uuids:
                audits_by_workflow = read_query_audits(log_conn, batch_workflow_uuids, args.batch_size)
            else:
                audits_by_workflow = {}
            snapshot_uuids = collect_snapshot_uuids(audits_by_workflow) if args.include_dml_snapshots else set()
            blob_meta = read_blob_meta(snapshot_conn, snapshot_uuids, args.batch_size) if args.include_dml_snapshots else {}
            found_audits += sum(len(value) for value in audits_by_workflow.values())
            snapshot_uuid_count += len(snapshot_uuids)

            for row in row_batch:
                print("Processing...", file=sys.stderr)
                workflow_uuid = normalize_uuid(row[workflow_col_index]) if len(row) > workflow_col_index else u""
                audits = audits_by_workflow.get(workflow_uuid, [])
                if not audits:
                    write_csv_row(
                        output_writer,
                        build_final_row(row, header_index, build_blank_enrichment(), internal_columns, workflow_uuid, column_specs),
                        args.encoding,
                    )
                    output_row_count += 1
                    continue

                for index, audit in enumerate(audits, 1):
                    try:
                        connection_database = get_base_value(
                            row,
                            header_index,
                            [u"Connection/DB명", u"DB명 (Connection/DB)", u"DB명", u"Connection / Database"],
                        )
                        enrichment_values = build_enrichment_for_audit(
                            audit,
                            index,
                            snapshot_conn,
                            blob_meta,
                            args.inline_threshold_bytes,
                            args.large_file_mode,
                            args.snapshot_output_dir,
                            connection_database,
                            ledger_data,
                            args.include_dml_snapshots,
                        )
                    except Exception:
                        log_audit_processing_error(workflow_uuid, audit, index)
                        enrichment_values = build_error_enrichment(
                            audit,
                            index,
                            u"DML snapshot 처리 중 오류가 발생했습니다. stderr 로그를 확인하세요.",
                        )
                    write_csv_row(
                        output_writer,
                        build_final_row(row, header_index, enrichment_values, internal_columns, workflow_uuid, column_specs),
                        args.encoding,
                    )
                    output_row_count += 1

        print("workflow rows: %s" % len(rows))
        print("unique workflow uuids: %s" % len(workflow_uuids))
        print("query audit rows: %s" % found_audits)
        print("snapshot uuids processed: %s" % snapshot_uuid_count)
        print("ledger table targets: %s" % len(ledger_data[0]))
        print("output rows: %s" % output_row_count)
        print("output: %s" % args.output)
        return 0
    finally:
        if output_fp is not None:
            output_fp.close()
        log_conn.close()
        if snapshot_conn is not None:
            snapshot_conn.close()
        app_conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
