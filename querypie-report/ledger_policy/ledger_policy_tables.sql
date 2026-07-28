-- Active Ledger policy targets across all DB connection types.
SELECT
    cg.name AS `Connection 이름`,
    cg.uuid AS `Connection Uuid`,
    lp.database_name AS `Database Name`,
    lpt.schema_name AS `Schema Name`,
    lpt.table_name AS `Table Name`,
    rule.name AS `Workflow Rule Name`
FROM querypie.ledger_policy_tables lpt
JOIN querypie.ledger_policies lp ON lp.policy_uuid = lpt.policy_uuid AND lp.deleted = 0
JOIN querypie.policies p ON p.uuid = lp.policy_uuid AND p.type = 'LEDGER' AND p.enabled = 1 AND p.deleted = 0
JOIN querypie.cluster_groups cg ON cg.uuid = p.object_uuid
INNER JOIN querypie.workflow_rules rule ON rule.uuid = lpt.workflow_rule_uuid
WHERE lpt.deleted = 0
ORDER BY cg.name, lp.database_name, lpt.table_name;
