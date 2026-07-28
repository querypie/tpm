-- Input dates are KST. The end date includes the entire specified KST day.
SET @start_kst = '2025-01-01 00:00:00';
SET @end_kst = '2025-12-31 00:00:00';

SELECT
    cg.name AS `커넥션명`, cg.db_type AS `DB 유형`, c.host AS `호스트`, c.port AS `포트`,
    u.login_id AS `로그인 ID`, u.name AS `사용자명`, u.email AS `이메일`, u.dept AS `부서`,
    cr.name AS `역할명`, cr.privilege_vendor AS `권한 DB 유형`, cr.privilege_types AS `권한 목록 (DML/DCL/DDL)`,
    CASE WHEN cr.can_import = 1 THEN 'Y' ELSE 'N' END AS `Can Import`,
    CASE WHEN cr.can_export = 1 THEN 'Y' ELSE 'N' END AS `Can Export`,
    CASE WHEN cr.can_copy_clipboard = 1 THEN 'Y' ELSE 'N' END AS `Can Copy to Clipboard`,
    -- Schema 권한이 활성화된 환경에서만 사용합니다. 그렇지 않으면 이 컬럼을 제거하세요.
    crm.schemas AS `스키마 범위 (NULL=전체)`,
    DATE_ADD(crm.granted_at, INTERVAL 9 HOUR) AS `권한 부여일시`,
    DATE_ADD(crm.expiry_at, INTERVAL 9 HOUR) AS `권한 만료일시 (NULL=무기한)`,
    CASE WHEN crm.enabled = 1 THEN '활성' ELSE '비활성' END AS `현재 상태`
FROM querypie.cluster_role_maps crm
JOIN querypie.users u ON u.id = crm.user_id AND u.deleted = 0
JOIN querypie.cluster_roles cr ON cr.id = crm.role_id AND cr.deleted = 0
LEFT JOIN querypie.clusters c ON c.id = crm.cluster_id AND c.deleted = 0
JOIN querypie.cluster_groups cg ON cg.id = crm.group_id AND cg.deleted = 0
WHERE crm.granted_at >= DATE_SUB(@start_kst, INTERVAL 9 HOUR)
  AND crm.granted_at < DATE_SUB(DATE_ADD(@end_kst, INTERVAL 1 DAY), INTERVAL 9 HOUR)
ORDER BY cg.name, c.host, u.login_id, crm.granted_at DESC;
