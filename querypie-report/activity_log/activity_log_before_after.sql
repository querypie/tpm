-- MySQL 8.0+ required for JSON_TABLE. Input and output dates use KST.
SET @start_kst = '2025-01-01 00:00:00';
SET @end_kst = '2025-12-31 23:59:59';

SELECT
    al.id AS event_id, al.uuid AS event_uuid,
    DATE_FORMAT(DATE_ADD(al.action_at, INTERVAL 9 HOUR), '%Y-%m-%d %H:%i:%s') AS action_at_kst,
    al.action_type AS event_type, al.target_type AS target_type, al.target_name AS target_name,
    al.target_uuid AS target_uuid, al.client_ip AS client_ip,
    u.name AS actor_name, u.email AS actor_email, u.dept AS actor_dept,
    d.`key`, d.`label`, d.`before`, d.`after`, d.has_changed, d.is_storable
FROM querypie_log.l_activity_logs al
LEFT JOIN querypie.users u ON u.id = al.action_by
JOIN JSON_TABLE(
    COALESCE(al.deltas, '[]'), '$[*]' COLUMNS (
        `key` VARCHAR(255) PATH '$.key', `label` VARCHAR(255) PATH '$.label',
        `before` TEXT PATH '$.before', `after` TEXT PATH '$.after',
        has_changed TINYINT(1) PATH '$.hasChanged', is_storable TINYINT(1) PATH '$.isStorable'
    )
) AS d
WHERE al.action_at >= DATE_SUB(@start_kst, INTERVAL 9 HOUR)
  AND al.action_at <= DATE_SUB(@end_kst, INTERVAL 9 HOUR)
ORDER BY al.action_at DESC, al.id;
