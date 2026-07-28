# Ledger 정책 테이블 조회

- `ledger_policy_tables.sql`: DB 유형과 관계없이 활성 Ledger 정책에 등록된 Connection, Database, Schema, Table, Workflow Rule 목록

`cluster_groups`의 DB 유형을 제한하지 않으므로 MongoDB를 포함한 모든 Connection 유형의 활성 Ledger 정책 대상을 출력합니다.

App DB(`querypie`) 읽기 권한이 필요합니다.

## 결과 컬럼

| 순서 | 컬럼 | 설명 |
| ---: | --- | --- |
| 1 | `Connection 이름` | Ledger 정책이 연결된 Connection 이름 (`cluster_groups.name`) |
| 2 | `Connection Uuid` | Ledger 정책이 연결된 Connection UUID (`cluster_groups.uuid`) |
| 3 | `Database Name` | Ledger Policy에 설정된 Database 이름 (`ledger_policies.database_name`) |
| 4 | `Schema Name` | Ledger 정책 테이블의 Schema 이름 (`ledger_policy_tables.schema_name`) |
| 5 | `Table Name` | Ledger 정책에 등록된 Table 또는 Collection 이름 (`ledger_policy_tables.table_name`) |
| 6 | `Workflow Rule Name` | 해당 Ledger 정책 테이블에 연결된 Workflow Rule 이름 (`workflow_rules.name`) |

삭제되지 않았고 활성화된 Ledger 정책 및 정책 테이블만 출력합니다. 결과는 Connection, Database, Table 이름 순으로 정렬됩니다.
