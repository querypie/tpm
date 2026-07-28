SET @start_kst = '2025-01-01 00:00:00';
SET @end_kst = '2025-02-01 00:00:00';

SELECT
    id,
    hash,
    user_id,
    user_login_id,
    user_name,
    user_email,
    action_type,
    DATE_ADD(acted_at, INTERVAL 9 HOUR) AS acted_at_kst,
    error,
    message,
    client_ip,
    host_name,
    actor_user_id,
    actor_user_name,
    created_by,
    DATE_ADD(created_at, INTERVAL 9 HOUR) AS created_at_kst
FROM querypie_log.l_user_auth_logs
WHERE action_type = 'LOGIN'
  AND error = 0
  AND acted_at >= DATE_SUB(@start_kst, INTERVAL 9 HOUR)
  AND acted_at < DATE_SUB(@end_kst, INTERVAL 9 HOUR)
ORDER BY acted_at;
