-- Connection Owner는 QueryPie의 사전 정의 역할입니다.
-- PredefinedRole.CONNECTION_OWNER UUID (현재 제품 기준):
-- c3594b76-5d4e-11ec-b114-0ab3e84d3368
SELECT
    cg.name AS `등록된 DB명`,
    COALESCE(GROUP_CONCAT(DISTINCT u.name ORDER BY u.name SEPARATOR ', '), '') AS `등록된 Connection Owner`
FROM querypie.cluster_groups cg
LEFT JOIN querypie.user_roles ur ON ur.object_type = 'CLUSTER_GROUP'
    AND ur.object_uuid = cg.uuid
    AND ur.role_uuid = 'c3594b76-5d4e-11ec-b114-0ab3e84d3368'
    AND ur.deleted = 0
LEFT JOIN querypie.users u ON u.uuid = ur.user_uuid AND u.deleted = 0
WHERE cg.deleted = 0
GROUP BY cg.uuid, cg.name
ORDER BY cg.name;
