SET @start_kst = '2024-01-01 00:00:00';
SET @end_kst = '2024-12-31 23:59:59';
SET @approver_email = CONVERT('approver@example.com' USING utf8mb4) COLLATE utf8mb4_general_ci;

SELECT
    DATE_ADD(wr.requested_at, INTERVAL 9 HOUR) AS requested_at_kst,
    wr.title, wr.requester_name, wr.requester_email,
    wr.requester_login_id, wr.approval_status,
    approver.user_name AS approver_name, approver.user_email AS approver_email,
    approver.user_login_id AS approver_login_id,
    DATE_ADD(wl.acted_at, INTERVAL 9 HOUR) AS approved_at_kst,
    wl.comments AS approval_comments
FROM querypie.workflow_requests wr
JOIN querypie_log.l_workflow_logs wl ON wl.workflow_uuid = wr.uuid
JOIN querypie_log.l_user_snapshots approver ON approver.id = wl.actor_snapshot_id
WHERE wr.request_type = 'SQL_EXECUTION'
  AND wl.action_type = 'WORKFLOW_APPROVED'
  AND wr.requested_at >= DATE_SUB(@start_kst, INTERVAL 9 HOUR)
  AND wr.requested_at <= DATE_SUB(@end_kst, INTERVAL 9 HOUR)
  AND approver.user_email = @approver_email
ORDER BY wr.requested_at DESC;
