SET @start_kst = '2025-01-01 00:00:00';
SET @end_kst = '2025-02-01 00:00:00';

SELECT
    DATE_ADD(acted_at, INTERVAL 9 HOUR) AS acted_at_kst,
    user_login_id, user_name, user_email, client_ip, host_name, message
FROM querypie_log.l_user_auth_logs FORCE INDEX (idx_createdat)
WHERE created_at >= DATE_SUB(@start_kst, INTERVAL 9 HOUR)
  AND created_at < DATE_SUB(@end_kst, INTERVAL 9 HOUR)
  AND action_type = 'LOGIN'
  AND error = 1;
