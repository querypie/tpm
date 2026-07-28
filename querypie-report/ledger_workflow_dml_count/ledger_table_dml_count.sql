SET @start_kst = '2025-01-01 00:00:00';
SET @end_kst   = '2026-01-01 00:00:00';
SET @tz_offset_hour = 9;

WITH RECURSIVE
ledger_targets AS (
    SELECT
        cg.uuid          AS cluster_group_uuid,
        cg.name          AS connection_name,
        lp.database_name AS database_name,
        lpt.schema_name  AS schema_name,
        lpt.table_name   AS table_name,
        wr.name          AS rule_name
    FROM querypie.ledger_policy_tables lpt
    JOIN querypie.ledger_policies lp
      ON lp.policy_uuid = lpt.policy_uuid
     AND lp.deleted = 0
    JOIN querypie.policies p
      ON p.uuid = lpt.policy_uuid
     AND p.deleted = 0
    JOIN querypie.cluster_groups cg
      ON cg.uuid = p.object_uuid
    JOIN querypie.workflow_rules wr
      ON wr.uuid = lpt.workflow_rule_uuid
     AND wr.deleted = 0
    WHERE lpt.deleted = 0
),
ledger_target_candidates AS (
    SELECT
        lt.*,
        lt.table_name AS candidate_object_name,
        1 AS requires_snapshot_db_match
    FROM ledger_targets lt

    UNION ALL

    SELECT
        lt.*,
        CONCAT(lt.database_name, '.', lt.table_name) AS candidate_object_name,
        0 AS requires_snapshot_db_match
    FROM ledger_targets lt

    UNION ALL

    SELECT
        lt.*,
        CONCAT(lt.schema_name, '.', lt.table_name) AS candidate_object_name,
        1 AS requires_snapshot_db_match
    FROM ledger_targets lt
    WHERE lt.schema_name IS NOT NULL

    UNION ALL

    SELECT
        lt.*,
        CONCAT(lt.database_name, '.', lt.schema_name, '.', lt.table_name) AS candidate_object_name,
        0 AS requires_snapshot_db_match
    FROM ledger_targets lt
    WHERE lt.schema_name IS NOT NULL
),
audit_base AS (
    SELECT
        l.uuid AS log_uuid,
        l.query_type,
        c.cluster_group_uuid,
        c.db_name,
        CAST(COALESCE(d.target_object_names, '') AS CHAR(4000)) AS target_object_names
    FROM querypie_log.l_query_execution_logs l
    JOIN querypie_log.l_db_connection_snapshots c
      ON c.id = l.db_connection_snapshot_id
    LEFT JOIN querypie_log.l_query_execution_log_details d
      ON d.id = l.id
    WHERE l.hidden = 0
      AND l.ledger = 1
      AND l.state = 1
      AND l.query_target_object_count > 0
      AND l.executed_at >= DATE_SUB(@start_kst, INTERVAL @tz_offset_hour HOUR)
      AND l.executed_at <  DATE_SUB(@end_kst,   INTERVAL @tz_offset_hour HOUR)
      AND COALESCE(d.target_object_names, '') <> ''
),
split_targets AS (
    SELECT
        log_uuid,
        query_type,
        cluster_group_uuid,
        db_name,
        CAST(TRIM(SUBSTRING_INDEX(target_object_names, ',', 1)) AS CHAR(1000)) AS object_name,
        CAST(
            CASE
                WHEN LOCATE(',', target_object_names) > 0
                THEN SUBSTRING(target_object_names, LOCATE(',', target_object_names) + 1)
                ELSE ''
            END AS CHAR(4000)
        ) AS rest
    FROM audit_base

    UNION ALL

    SELECT
        log_uuid,
        query_type,
        cluster_group_uuid,
        db_name,
        CAST(TRIM(SUBSTRING_INDEX(rest, ',', 1)) AS CHAR(1000)) AS object_name,
        CAST(
            CASE
                WHEN LOCATE(',', rest) > 0
                THEN SUBSTRING(rest, LOCATE(',', rest) + 1)
                ELSE ''
            END AS CHAR(4000)
        ) AS rest
    FROM split_targets
    WHERE rest <> ''
),
normalized_targets AS (
    SELECT DISTINCT
        log_uuid,
        query_type,
        cluster_group_uuid,
        db_name,
        TRIM(REPLACE(REPLACE(REPLACE(object_name, '`', ''), '"', ''), '''', '')) AS object_name
    FROM split_targets
    WHERE object_name <> ''
)
SELECT
    ltc.connection_name AS `Connection`,
    ltc.database_name   AS `Database`,
    ltc.schema_name     AS `Schema`,
    ltc.table_name      AS `Table`,
    ltc.rule_name       AS `RuleName`,
    COUNT(DISTINCT CASE WHEN nt.query_type IN (3, 4, 5, 6, 7, 8) THEN nt.log_uuid END) AS `DML 개수`
FROM ledger_target_candidates ltc
LEFT JOIN normalized_targets nt
  ON nt.cluster_group_uuid COLLATE utf8mb4_general_ci
   = ltc.cluster_group_uuid COLLATE utf8mb4_general_ci
 AND nt.object_name COLLATE utf8mb4_general_ci
   = ltc.candidate_object_name COLLATE utf8mb4_general_ci
 AND (
        ltc.requires_snapshot_db_match = 0
        OR nt.db_name COLLATE utf8mb4_general_ci
         = ltc.database_name COLLATE utf8mb4_general_ci
     )
GROUP BY
    ltc.connection_name,
    ltc.database_name,
    ltc.schema_name,
    ltc.table_name,
    ltc.rule_name
ORDER BY
    ltc.connection_name,
    ltc.database_name,
    ltc.schema_name,
    ltc.table_name,
    ltc.rule_name;
