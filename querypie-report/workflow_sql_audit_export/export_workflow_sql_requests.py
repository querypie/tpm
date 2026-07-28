#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Export SQL workflow requests to CSV, optionally filtered by approval rule names.

Python 2.7 compatible. DB timestamps are stored in UTC; date filter arguments
are accepted as KST and output timestamps are rendered as KST.
"""
from __future__ import print_function

import argparse
import csv
import os
import re
import sys
from datetime import datetime, timedelta


PY2 = sys.version_info[0] == 2
KST_OFFSET = timedelta(hours=9)
DATETIME_FORMAT = "%Y-%m-%d %H:%M:%S"
URL_PATTERN = re.compile(r"https?://[^\s,;\"'<>]+")
ISSUE_KEY_PATTERN = re.compile(r"\b[A-Za-z]{3,}-\d+\b")


class DbConfig(object):
    def __init__(self, host, port, user, password, database, charset="utf8mb4"):
        self.host = host
        self.port = int(port)
        self.user = user
        self.password = password
        self.database = database
        self.charset = charset


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
    return "utf-8" if encoding.lower().replace("_", "-") == "utf-8-sig" else encoding


def to_csv_cell(value, encoding):
    text = to_text(value)
    return text.encode(csv_cell_encoding(encoding)) if PY2 else text


def env_or_default(name, default=None):
    value = os.environ.get(name)
    return value if value not in (None, "") else default


def split_approval_rule_names(values):
    """Accept repeated --approval-rule-name arguments and comma-separated names."""
    result = []
    seen = set()
    for value in values:
        for item in to_text(value).split(","):
            name = item.strip()
            if name and name not in seen:
                seen.add(name)
                result.append(name)
    return result


def parse_kst_datetime(value, end_of_day=False):
    text = value.strip()
    if len(text) == 10:
        text += " 23:59:59" if end_of_day else " 00:00:00"
    try:
        return datetime.strptime(text, DATETIME_FORMAT)
    except ValueError:
        raise SystemExit("Invalid datetime format: %s. Use YYYY-MM-DD or YYYY-MM-DD HH:MM:SS." % value)


def format_datetime(value):
    if value is None:
        return u""
    if isinstance(value, datetime):
        return value.strftime(DATETIME_FORMAT)
    return to_text(value)


def add_vendor_dir(vendor_dir):
    if not vendor_dir:
        return
    if not os.path.isdir(vendor_dir):
        raise SystemExit("Vendor directory does not exist: %s" % vendor_dir)
    abs_vendor_dir = os.path.abspath(vendor_dir)
    if abs_vendor_dir not in sys.path:
        sys.path.insert(0, abs_vendor_dir)


def parse_args():
    parser = argparse.ArgumentParser(description="Export SQL workflow requests to CSV.")
    parser.add_argument("--output", required=True, help="Output CSV path.")
    parser.add_argument(
        "--rows-per-file",
        type=int,
        default=200,
        help="Maximum data rows per output CSV file. Use 0 to disable splitting. Default: 200.",
    )
    parser.add_argument(
        "--from-kst",
        default="2020-06-01 00:00:00",
        help="Requested-at start time in KST. Inclusive. Default: 2020-06-01 00:00:00.",
    )
    parser.add_argument(
        "--to-kst",
        default="2026-08-01 00:00:00",
        help="Requested-at end time in KST. Exclusive. Default: 2026-08-01 00:00:00.",
    )
    parser.add_argument("--encoding", default="utf-8-sig", help="Output CSV encoding. Default: utf-8-sig.")
    parser.add_argument("--fetch-size", type=int, default=1000, help="Rows to fetch per DB round-trip. Default: 1000.")
    parser.add_argument(
        "--approval-rule-name",
        action="append",
        default=[],
        help="Filter by approval rule name. Accepts comma-separated names and can be specified multiple times. Default: all approval rule names.",
    )
    parser.add_argument(
        "--vendor-dir",
        default=env_or_default("QUERYPIE_AUDIT_VENDOR_DIR"),
        help="Directory containing pre-downloaded Python packages. Also configurable with QUERYPIE_AUDIT_VENDOR_DIR.",
    )

    parser.add_argument("--db-host", "--log-db-host", dest="db_host", default=env_or_default("QUERYPIE_DB_HOST", env_or_default("QUERYPIE_LOG_DB_HOST", "127.0.0.1")))
    parser.add_argument("--db-port", "--log-db-port", dest="db_port", type=int, default=int(env_or_default("QUERYPIE_DB_PORT", env_or_default("QUERYPIE_LOG_DB_PORT", "3306")) or "3306"))
    parser.add_argument("--db-user", "--log-db-user", dest="db_user", default=env_or_default("QUERYPIE_DB_USER", env_or_default("QUERYPIE_LOG_DB_USER", "querypie")))
    parser.add_argument("--db-password", "--log-db-password", dest="db_password", default=env_or_default("QUERYPIE_DB_PASSWORD", env_or_default("QUERYPIE_LOG_DB_PASSWORD", "querypie")))
    parser.add_argument("--db-name", "--log-db-name", dest="db_name", default=env_or_default("QUERYPIE_DB_NAME", env_or_default("QUERYPIE_LOG_DB_NAME", "querypie")))
    args = parser.parse_args()
    if args.rows_per_file < 0:
        raise SystemExit("--rows-per-file must be 0 or greater.")
    args.approval_rule_name = split_approval_rule_names(args.approval_rule_name)
    return args


def connect(config, streaming=False):
    try:
        import pymysql

        cursor_class = pymysql.cursors.SSCursor if streaming else pymysql.cursors.Cursor
        return pymysql.connect(
            host=config.host,
            port=config.port,
            user=config.user,
            password=config.password,
            database=config.database,
            charset=config.charset,
            cursorclass=cursor_class,
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


def open_csv_writer(path, encoding):
    parent = os.path.dirname(os.path.abspath(path))
    if parent and not os.path.exists(parent):
        os.makedirs(parent)

    if PY2:
        fp = open(path, "wb")
        if encoding.lower().replace("_", "-") == "utf-8-sig":
            fp.write(u"\ufeff".encode("utf-8"))
        return fp, csv.writer(fp, quoting=csv.QUOTE_ALL)

    fp = open(path, "w", newline="", encoding=encoding)
    return fp, csv.writer(fp, quoting=csv.QUOTE_ALL)


def write_row(writer, row, encoding):
    writer.writerow([to_csv_cell(cell, encoding) for cell in row])


def extract_unique_urls(value):
    urls = []
    seen = set()
    for match in URL_PATTERN.findall(to_text(value)):
        url = match.rstrip(u".)]}")
        seen.add(url)
    for match in ISSUE_KEY_PATTERN.findall(to_text(value)):
        key = to_text(match).upper()
        seen.add(key)
    return u", ".join(list(seen))


def transform_export_row(row):
    values = list(row)
    if len(values) >= 21:
        values[20] = extract_unique_urls(values[8])
    return values


def split_output_path(output_path, file_index):
    #if file_index <= 1:
    #    return output_path
    base, ext = os.path.splitext(output_path)
    if not ext:
        ext = ".csv"
    return "%s.%03d%s" % (base, file_index, ext)


def export_rows(conn, output_path, from_utc, to_utc, encoding, fetch_size, rows_per_file, approval_rule_names):
    approval_rule_filter = ""
    if approval_rule_names:
        approval_rule_filter = "          AND rule.name IN (%s)\n" % ",".join(["%s"] * len(approval_rule_names))

    sql = """
        WITH approval_lines AS (
            SELECT
                a.workflow_request_uuid,

                GROUP_CONCAT(
                    CASE WHEN a.`order` = 0 AND a.status IN ('APPROVED', 'REJECTED') THEN
                        CONCAT(
                            CASE a.status
                                WHEN 'REJECTED' THEN 'REJECT '
                                ELSE ''
                            END,
                            COALESCE(
                                NULLIF(a.actor_login_id, ''),
                                NULLIF(actor.login_id, ''),
                                NULLIF(a.action_by_uuid, ''),
                                NULLIF(a.api_user_uuid, ''),
                                'UNKNOWN'
                            )
                        )
                    END
                    ORDER BY a.action_at, COALESCE(a.actor_login_id, actor.login_id, a.action_by_uuid)
                    SEPARATOR ', '
                ) AS approval_step_1,

                GROUP_CONCAT(
                    CASE WHEN a.`order` = 0 AND a.status IN ('APPROVED', 'REJECTED') THEN
                        DATE_FORMAT(DATE_ADD(a.action_at, INTERVAL 9 HOUR), '%%Y-%%m-%%d %%H:%%i:%%s')
                    END
                    ORDER BY a.action_at, COALESCE(a.actor_login_id, actor.login_id, a.action_by_uuid)
                    SEPARATOR ', '
                ) AS approval_step_1_at,

                GROUP_CONCAT(
                    CASE WHEN a.`order` = 1 AND a.status IN ('APPROVED', 'REJECTED') THEN
                        CONCAT(
                            CASE a.status
                                WHEN 'REJECTED' THEN 'REJECT '
                                ELSE ''
                            END,
                            COALESCE(
                                NULLIF(a.actor_login_id, ''),
                                NULLIF(actor.login_id, ''),
                                NULLIF(a.action_by_uuid, ''),
                                NULLIF(a.api_user_uuid, ''),
                                'UNKNOWN'
                            )
                        )
                    END
                    ORDER BY a.action_at, COALESCE(a.actor_login_id, actor.login_id, a.action_by_uuid)
                    SEPARATOR ', '
                ) AS approval_step_2,

                GROUP_CONCAT(
                    CASE WHEN a.`order` = 1 AND a.status IN ('APPROVED', 'REJECTED') THEN
                        DATE_FORMAT(DATE_ADD(a.action_at, INTERVAL 9 HOUR), '%%Y-%%m-%%d %%H:%%i:%%s')
                    END
                    ORDER BY a.action_at, COALESCE(a.actor_login_id, actor.login_id, a.action_by_uuid)
                    SEPARATOR ', '
                ) AS approval_step_2_at,

                GROUP_CONCAT(
                    CASE WHEN a.`order` = 2 AND a.status IN ('APPROVED', 'REJECTED') THEN
                        CONCAT(
                            CASE a.status
                                WHEN 'REJECTED' THEN 'REJECT '
                                ELSE ''
                            END,
                            COALESCE(
                                NULLIF(a.actor_login_id, ''),
                                NULLIF(actor.login_id, ''),
                                NULLIF(a.action_by_uuid, ''),
                                NULLIF(a.api_user_uuid, ''),
                                'UNKNOWN'
                            )
                        )
                    END
                    ORDER BY a.action_at, COALESCE(a.actor_login_id, actor.login_id, a.action_by_uuid)
                    SEPARATOR ', '
                ) AS approval_step_3,

                GROUP_CONCAT(
                    CASE WHEN a.`order` = 2 AND a.status IN ('APPROVED', 'REJECTED') THEN
                        DATE_FORMAT(DATE_ADD(a.action_at, INTERVAL 9 HOUR), '%%Y-%%m-%%d %%H:%%i:%%s')
                    END
                    ORDER BY a.action_at, COALESCE(a.actor_login_id, actor.login_id, a.action_by_uuid)
                    SEPARATOR ', '
                ) AS approval_step_3_at,

                GROUP_CONCAT(
                    CASE WHEN a.`order` = 3 AND a.status IN ('APPROVED', 'REJECTED') THEN
                        CONCAT(
                            CASE a.status
                                WHEN 'REJECTED' THEN 'REJECT '
                                ELSE ''
                            END,
                            COALESCE(
                                NULLIF(a.actor_login_id, ''),
                                NULLIF(actor.login_id, ''),
                                NULLIF(a.action_by_uuid, ''),
                                NULLIF(a.api_user_uuid, ''),
                                'UNKNOWN'
                            )
                        )
                    END
                    ORDER BY a.action_at, COALESCE(a.actor_login_id, actor.login_id, a.action_by_uuid)
                    SEPARATOR ', '
                ) AS approval_step_4,

                GROUP_CONCAT(
                    CASE WHEN a.`order` = 3 AND a.status IN ('APPROVED', 'REJECTED') THEN
                        DATE_FORMAT(DATE_ADD(a.action_at, INTERVAL 9 HOUR), '%%Y-%%m-%%d %%H:%%i:%%s')
                    END
                    ORDER BY a.action_at, COALESCE(a.actor_login_id, actor.login_id, a.action_by_uuid)
                    SEPARATOR ', '
                ) AS approval_step_4_at
            FROM querypie.workflow_request_approval_assignees a
            LEFT JOIN querypie.users actor
                   ON actor.uuid = a.action_by_uuid
            GROUP BY a.workflow_request_uuid
        )
        SELECT
            wr.id AS workflow_id,
            wr.approval_status,
            wr.execution_status,
            DATE_FORMAT(
                DATE_ADD(wr.requested_at, INTERVAL 9 HOUR),
                '%%Y-%%m-%%d %%H:%%i:%%s'
            ) AS `workflow 상신일`,
            CASE WHEN COALESCE(wr.urgent, 0) = 1 THEN 'Y' ELSE 'N' END AS `사후결제여부`,
            DATE_FORMAT(
                DATE_ADD(ex.executed_at, INTERVAL 9 HOUR),
                '%%Y-%%m-%%d %%H:%%i:%%s'
            ) AS `변경수행일`,
            wr.requester_login_id AS `변경요청자`,
            wr.title AS `변경제목`,
            wr.comments AS `변경사유`,
            CONCAT_WS(' / ', NULLIF(cg.name, ''), NULLIF(se.`database`, '')) AS `DB명 (Connection/DB)`,
            wr.requester_login_id AS `요청자`,
            ex.execution_assignees AS `수행자`,
            al.approval_step_1 AS `1차승인자`,
            al.approval_step_1_at AS `1차승인일시`,
            al.approval_step_2 AS `2차승인자`,
            al.approval_step_2_at AS `2차승인일시`,
            al.approval_step_3 AS `3차승인자`,
            al.approval_step_3_at AS `3차승인일시`,
            al.approval_step_4 AS `4차승인자`,
            al.approval_step_4_at AS `4차승인일시`,
            '' AS `변경요청 근거 (관리툴 링크)`,
            wr.uuid AS workflow_uuid,
            CASE WHEN COALESCE(wr.ledger, 0) = 1 THEN 'Y' ELSE 'N' END AS `Workflow Ledger 여부`,
            CASE WHEN COALESCE(rule.ledger, 0) = 1 THEN 'Y' ELSE 'N' END AS `결제선 Ledger 여부`,
            CASE
                WHEN rule.name = 'Ledger Rule' THEN 'Ledger'
                WHEN rule.name = 'Privacy Rule' THEN 'Privacy'
                ELSE rule.name
            END AS rule_name
        FROM querypie.workflow_requests wr
        LEFT JOIN querypie.workflow_rules rule
               ON rule.uuid = wr.rule_uuid
        LEFT JOIN querypie.workflow_request_detail_sql_executions se
               ON se.workflow_request_uuid = wr.uuid
        LEFT JOIN querypie.clusters c
               ON c.uuid = se.object_uuid
        LEFT JOIN querypie.cluster_groups cg
               ON cg.id = c.group_id
        LEFT JOIN approval_lines al
               ON al.workflow_request_uuid = wr.uuid
        LEFT JOIN (
            SELECT
                e.workflow_request_uuid,
                MIN(
                    CASE
                        WHEN e.status = 'EXECUTED' THEN e.action_at
                    END
                ) AS executed_at,
                GROUP_CONCAT(
                    COALESCE(
                        NULLIF(e.actor_login_id, ''),
                        NULLIF(actor.login_id, ''),
                        NULLIF(e.user_login_id, ''),
                        NULLIF(assignee.login_id, ''),
                        NULLIF(e.action_by_uuid, ''),
                        NULLIF(e.user_uuid, ''),
                        NULLIF(e.api_user_uuid, ''),
                        'UNKNOWN'
                    )
                    ORDER BY e.action_at, e.finished_at, COALESCE(e.actor_login_id, e.user_login_id, e.action_by_uuid, e.user_uuid)
                    SEPARATOR ', '
                ) AS execution_assignees
            FROM querypie.workflow_request_execution_assignees e
            LEFT JOIN querypie.users assignee
                   ON assignee.uuid = e.user_uuid
            LEFT JOIN querypie.users actor
                   ON actor.uuid = e.action_by_uuid
            WHERE e.status IN ('EXECUTED', 'CANCELED')
            GROUP BY e.workflow_request_uuid
        ) ex
               ON ex.workflow_request_uuid = wr.uuid
        WHERE wr.requested_at >= %s
          AND wr.requested_at <  %s
          AND wr.request_type = 'SQL_EXECUTION'
          AND wr.approval_status = 'APPROVED'
          AND wr.execution_status = 'SUCCESS'
{approval_rule_filter}
        ORDER BY wr.id ASC
    """.format(approval_rule_filter=approval_rule_filter)
    header = [
        u"workflow_id",
        u"승인 상태",
        u"실행 상태",
        u"workflow 상신일",
        u"사후결제여부",
        u"변경수행일",
        u"변경요청자",
        u"변경제목",
        u"변경사유",
        u"DB명 (Connection/DB)",
        u"요청자",
        u"수행자",
        u"1차승인자",
        u"1차승인일시",
        u"2차승인자",
        u"2차승인일시",
        u"3차승인자",
        u"3차승인일시",
        u"4차승인자",
        u"4차승인일시",
        u"변경요청 근거 (관리툴 링크)",
        u"workflow_uuid",
        u"Workflow Ledger 여부",
        u"결제선 Ledger 여부",
        u"rule_name",
    ]

    cursor = conn.cursor()
    fp = None
    writer = None
    count = 0
    output_paths = []

    def open_next_file():
        path = split_output_path(output_path, len(output_paths) + 1)
        next_fp, next_writer = open_csv_writer(path, encoding)
        write_row(next_writer, header, encoding)
        output_paths.append(path)
        return next_fp, next_writer

    try:
        try:
            cursor.execute("SET SESSION group_concat_max_len = 1048576")
        except Exception:
            pass

        params = [format_datetime(from_utc), format_datetime(to_utc)] + approval_rule_names
        cursor.execute(sql, params)
        fp, writer = open_next_file()

        while True:
            rows = cursor.fetchmany(fetch_size)
            if not rows:
                break
            for row in rows:
                if rows_per_file > 0 and count > 0 and count % rows_per_file == 0:
                    fp.close()
                    fp, writer = open_next_file()
                write_row(writer, transform_export_row(row), encoding)
                count += 1
    finally:
        cursor.close()
        if fp is not None:
            fp.close()
    return count, output_paths


def main():
    args = parse_args()
    add_vendor_dir(args.vendor_dir)

    from_kst = parse_kst_datetime(args.from_kst)
    to_kst = parse_kst_datetime(args.to_kst)
    if from_kst >= to_kst:
        raise SystemExit("--from-kst must be earlier than --to-kst")

    from_utc = from_kst - KST_OFFSET
    to_utc = to_kst - KST_OFFSET

    db_config = DbConfig(
        host=args.db_host,
        port=args.db_port,
        user=args.db_user,
        password=args.db_password,
        database=args.db_name,
    )
    conn = connect(db_config, streaming=True)
    try:
        count, output_paths = export_rows(
            conn,
            args.output,
            from_utc,
            to_utc,
            args.encoding,
            args.fetch_size,
            args.rows_per_file,
            args.approval_rule_name,
        )
    finally:
        conn.close()

    print("from_kst: %s" % format_datetime(from_kst))
    print("to_kst: %s" % format_datetime(to_kst))
    print("from_utc: %s" % format_datetime(from_utc))
    print("to_utc: %s" % format_datetime(to_utc))
    print("exported rows: %s" % count)
    if args.approval_rule_name:
        print("approval_rule_names: %s" % ", ".join(args.approval_rule_name))
    print("output files: %s" % len(output_paths))
    for output_path in output_paths:
        print("output: %s" % output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
