-- Successful Query Audit detail report. Dates are KST.
SET @start_kst = '2025-06-01 00:00:00';
SET @end_kst = '2025-06-20 00:00:00';

SELECT
    l.id AS `No`,
    ANY_VALUE(DATE_ADD(l.executed_at, INTERVAL 9 HOUR)) AS `Executed At`,
    ANY_VALUE(CASE l.state WHEN 1 THEN 'SUCCESS' WHEN 2 THEN 'FAILURE' WHEN 3 THEN 'STOPPED' WHEN 5 THEN 'RUNNING' WHEN 6 THEN 'ABORTED' ELSE 'unknown' END) AS `Result`,
    ANY_VALUE(u.user_name) AS `Name`,
    ANY_VALUE(u.user_email) AS `Email`,
    ANY_VALUE(CASE l.action_type WHEN 0 THEN 'Connection' WHEN 1 THEN 'SQL Execution' WHEN 2 THEN 'Export Data' WHEN 3 THEN 'Export Schema' WHEN 4 THEN 'Import Data' WHEN 5 THEN 'Import Schema' WHEN 6 THEN 'Copy Clipboard' ELSE 'unknown' END) AS `Action Type`,
    ANY_VALUE(c.cluster_group_name) AS `Connection Name`,
    ANY_VALUE(c.db_type) AS `Database Type`,
    ANY_VALUE(r.cluster_role_name) AS `Privilege Name`,
    ANY_VALUE(l.client_ip) AS `Client IP`,
    ANY_VALUE(c.cluster_repl_type) AS `Replication Type`,
    ANY_VALUE(c.db_host) AS `DB Host`,
    ANY_VALUE(c.db_name) AS `DB Name`,
    ANY_VALUE(l.db_user) AS `DB User`,
    ANY_VALUE(COALESCE(ld.target_object_names, '')) AS `Table(s)`,
    ANY_VALUE(CASE l.query_type WHEN 0 THEN 'Unknown' WHEN 1 THEN 'With' WHEN 2 THEN 'Select' WHEN 3 THEN 'Insert' WHEN 4 THEN 'Upsert' WHEN 5 THEN 'Replace' WHEN 6 THEN 'Update' WHEN 7 THEN 'Delete' WHEN 8 THEN 'MergeInto' WHEN 9 THEN 'Create' WHEN 10 THEN 'Alter' WHEN 11 THEN 'Drop' WHEN 12 THEN 'Rename' WHEN 13 THEN 'Truncate' WHEN 14 THEN 'Grant' WHEN 15 THEN 'Revoke' WHEN 16 THEN 'Commit' WHEN 17 THEN 'Rollback' WHEN 18 THEN 'SavePoint' WHEN 19 THEN 'Prepare' WHEN 20 THEN 'DropPrepare' WHEN 21 THEN 'Execute' WHEN 22 THEN 'Delimiter' WHEN 23 THEN 'Call' WHEN 24 THEN 'Explain' WHEN 25 THEN 'Use' WHEN 26 THEN 'Show' WHEN 27 THEN 'Describe' WHEN 28 THEN 'Set' WHEN 29 THEN 'Begin' WHEN 30 THEN 'Comment' WHEN 31 THEN 'Trivia' ELSE 'unknown' END) AS `SQL Type`,
    ANY_VALUE(l.query_text) AS `Query`,
    ANY_VALUE(l.processing_millis) AS `Time(ms)`,
    ANY_VALUE(COALESCE(l.processed_record_count, '')) AS `Rows`,
    ANY_VALUE(COALESCE(l.processed_record_byte_count, '')) AS `Data Size`,
    ANY_VALUE(COALESCE(l.client_name, '')) AS `Client Name`,
    ANY_VALUE(COALESCE(ld.error_message, '')) AS `Error Message`,
    ANY_VALUE(COALESCE(ld.action_comment, '')) AS `Execution Reason`,
    ANY_VALUE(CASE l.prevented WHEN 0 THEN 'Not Prevented' WHEN 1 THEN 'Prevented' END) AS `Prevented`,
    ANY_VALUE(CASE l.ledger WHEN 0 THEN 'Normal' WHEN 1 THEN 'Ledger' END) AS `Label`,
    ANY_VALUE(CASE l.action_origin_type WHEN 1 THEN 'Web Editor' WHEN 2 THEN 'Proxy' WHEN 3 THEN 'SQL Request' WHEN 4 THEN 'SQL Job' WHEN 5 THEN 'SQL Export Request' ELSE '' END) AS `Executed From`
FROM querypie_log.l_query_execution_logs l
LEFT JOIN querypie_log.l_query_execution_log_details ld ON ld.id = l.id
LEFT JOIN querypie_log.l_db_connection_snapshots c ON c.id = l.db_connection_snapshot_id
LEFT JOIN querypie_log.l_user_snapshots u ON u.id = l.user_snapshot_id
LEFT JOIN querypie_log.l_cluster_role_snapshots r ON r.id = ld.cluster_role_snapshot_ids
WHERE l.state = 1
  AND l.executed_at >= DATE_SUB(@start_kst, INTERVAL 9 HOUR)
  AND l.executed_at < DATE_SUB(@end_kst, INTERVAL 9 HOUR)
GROUP BY l.id
ORDER BY l.id DESC;
