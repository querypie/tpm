-- Successful SQL Workflow requests with INSERT, UPDATE, and DELETE audits.
SET @start_kst = '2026-01-01 00:00:00';
SET @end_kst = '2026-04-01 00:00:00';

SELECT
    wr.id AS request_id, wr.uuid AS request_uuid, wr.title,
    DATE_ADD(wr.requested_at, INTERVAL 9 HOUR) AS requested_at_kst,
    wr.requester_name, wr.requester_email, wr.execution_status,
    qel.query_request_sub_query_index AS sub_query_index,
    DATE_ADD(qel.executed_at, INTERVAL 9 HOUR) AS executed_at_kst,
    CASE qel.query_type WHEN 3 THEN 'INSERT' WHEN 6 THEN 'UPDATE' WHEN 7 THEN 'DELETE' ELSE 'OTHER' END AS sql_type,
    qel.query_text AS executed_query, COALESCE(qel.processed_record_count, 0) AS processed_rows,
    CASE qel.state WHEN 1 THEN 'SUCCESS' WHEN 2 THEN 'FAILURE' WHEN 3 THEN 'STOPPED' WHEN 5 THEN 'RUNNING' WHEN 6 THEN 'ABORTED' ELSE 'UNKNOWN' END AS query_result
FROM querypie.workflow_requests wr
JOIN querypie_log.l_query_execution_logs qel ON qel.query_request_uuid = wr.uuid
WHERE wr.request_type = 'SQL_EXECUTION'
  AND wr.execution_status = 'SUCCESS'
  AND wr.requested_at >= DATE_SUB(@start_kst, INTERVAL 9 HOUR)
  AND wr.requested_at < DATE_SUB(@end_kst, INTERVAL 9 HOUR)
  AND qel.query_type IN (3, 6, 7)
ORDER BY wr.requested_at DESC, qel.query_request_sub_query_index ASC;
