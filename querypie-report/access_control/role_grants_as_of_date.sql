SET @as_of_date = '2026-03-31';
-- Explicitly match cluster_groups.name's legacy utf8mb4 collation.
SET @connection_name = CONVERT('connection-name' USING utf8mb4) COLLATE utf8mb4_general_ci;

SELECT
    u.type AS `User Type`, u.name AS `User Name`, cg.name AS `Connection Name`, c.host AS `DB Host`,
    CASE c.repl_type WHEN 'MASTER' THEN 'PRIMARY' WHEN 'SLAVE' THEN 'SECONDARY' WHEN 'SINGLE' THEN 'SINGLE' ELSE '' END AS `Replication Type`,
    cr.name AS `Role Name`,
    CASE WHEN crm.enabled = 0 THEN 'Deactivated' WHEN crm.enabled = 1 THEN 'Active' WHEN crm.expired = 1 THEN 'Expired' ELSE '' END AS `Status`,
    DATE_ADD(crm.granted_at, INTERVAL 9 HOUR) AS `Granted At`, COALESCE(DATE_ADD(crm.expiry_at, INTERVAL 9 HOUR), '') AS `Expiration At`,
    COALESCE(DATE_ADD(crm.renew_at, INTERVAL 9 HOUR), '') AS `Renewed At`,
    COALESCE(DATE_ADD(crm.last_access_at, INTERVAL 9 HOUR), '') AS `Last Access At`
FROM querypie.cluster_role_maps crm
LEFT JOIN querypie.users u ON u.id = crm.user_id
LEFT JOIN querypie.clusters c ON c.id = crm.cluster_id
LEFT JOIN querypie.cluster_groups cg ON cg.id = c.group_id
LEFT JOIN querypie.cluster_roles cr ON cr.id = crm.role_id
WHERE crm.deleted = 0 AND u.deleted = 0
  AND @as_of_date BETWEEN DATE(DATE_ADD(crm.granted_at, INTERVAL 9 HOUR))
      AND COALESCE(DATE(DATE_ADD(crm.expiry_at, INTERVAL 9 HOUR)), '9999-12-31')
  AND cg.name = @connection_name
ORDER BY crm.granted_at DESC;
