SET SESSION group_concat_max_len = 1000000;

SELECT
    cg.uuid AS connection_uuid,
    cg.name AS connection_name,
    COUNT(DISTINCT gu.user_uuid) AS assigned_user_count,
    COALESCE(GROUP_CONCAT(DISTINCT CONCAT(gu.login_id, ' (', gu.user_name, ')') ORDER BY gu.login_id SEPARATOR ', '), '') AS assigned_users
FROM querypie.cluster_groups cg
LEFT JOIN (
    SELECT DISTINCT crm.group_id, u.uuid AS user_uuid, u.login_id, u.name AS user_name
    FROM querypie.cluster_role_maps crm
    JOIN querypie.clusters c ON c.id = crm.cluster_id AND c.group_id = crm.group_id AND c.deleted = 0
    JOIN querypie.users u ON u.id = crm.user_id AND u.type = 'USER' AND u.deleted = 0
    WHERE crm.deleted = 0 AND crm.enabled = 1 AND crm.expired = 0 AND (crm.expiry_at IS NULL OR crm.expiry_at > UTC_TIMESTAMP())
    UNION
    SELECT DISTINCT crm.group_id, member.uuid AS user_uuid, member.login_id, member.name AS user_name
    FROM querypie.cluster_role_maps crm
    JOIN querypie.clusters c ON c.id = crm.cluster_id AND c.group_id = crm.group_id AND c.deleted = 0
    JOIN querypie.users g ON g.id = crm.user_id AND g.type = 'GROUP' AND g.deleted = 0
    JOIN querypie.user_group_users ugu ON ugu.user_group_uuid = g.uuid AND ugu.deleted = 0
    JOIN querypie.users member ON member.uuid = ugu.user_uuid AND member.type = 'USER' AND member.deleted = 0
    WHERE crm.deleted = 0 AND crm.enabled = 1 AND crm.expired = 0 AND (crm.expiry_at IS NULL OR crm.expiry_at > UTC_TIMESTAMP())
) gu ON gu.group_id = cg.id
WHERE cg.deleted = 0
GROUP BY cg.uuid, cg.name
ORDER BY cg.name;
