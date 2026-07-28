-- Connection Owner는 QueryPie의 사전 정의 역할입니다.
-- PredefinedRole.CONNECTION_OWNER UUID (현재 제품 기준):
-- c3594b76-5d4e-11ec-b114-0ab3e84d3368
-- Connection별 Owner를 사용자 단위로 한 행씩 조회합니다.

SELECT
    cg.uuid AS `Connection UUID`,
    cg.name AS `Connection Name`,
    u.uuid AS `User UUID`,
    u.login_id AS `Login ID`,
    u.name AS `User Name`,
    u.email AS `Email`,
    DATE_ADD(ur.created_at, INTERVAL 9 HOUR) AS `Assigned At`
FROM querypie.cluster_groups cg
INNER JOIN querypie.user_roles ur ON ur.object_type = 'CLUSTER_GROUP'
    AND ur.object_uuid = cg.uuid
    AND ur.role_uuid = 'c3594b76-5d4e-11ec-b114-0ab3e84d3368'
    AND ur.deleted = 0
INNER JOIN querypie.users u ON u.uuid = ur.user_uuid
    AND u.deleted = 0
WHERE cg.deleted = 0
ORDER BY cg.name, u.name, u.login_id;
