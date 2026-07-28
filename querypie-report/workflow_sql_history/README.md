# Workflow SQL 이력 조회

SQL 실행 Workflow의 DML 실행 이력과 승인 처리 이력을 조회하는 SQL 모음입니다. 모두 읽기 전용이며 App DB(`querypie`)와 Log DB(`querypie_log`)에 대한 조회 권한이 필요합니다.

## 파일 선택

| 파일 | 사용 목적 | 주요 입력 |
| --- | --- | --- |
| `successful_dml_requests.sql` | 성공한 SQL Workflow의 `INSERT`·`UPDATE`·`DELETE` 실행 이력 | 시작 시각, 종료 시각 |
| `ledger_dml_requests.sql` | Ledger로 표시된 SQL Workflow의 `INSERT`·`UPDATE`·`DELETE` 실행 이력 | 시작 시각, 종료 시각 |
| `approvals_by_approver.sql` | 특정 승인자가 승인 처리한 SQL Workflow 이력 | 시작 시각, 종료 시각, 승인자 이메일 |

## 공통 실행 방법

조회하려는 파일 상단의 변수를 수정한 뒤 QueryPie App DB에 연결하여 실행합니다. DML 실행 이력 SQL은 다음처럼 종료 시각을 **미포함**으로 사용합니다.

```sql
SET @start_kst = '2026-01-01 00:00:00';
SET @end_kst = '2026-04-01 00:00:00';
```

위 예시는 2026-01-01 00:00:00 이상, 2026-04-01 00:00:00 미만을 의미합니다. 월 단위 추출 시 다음 달 1일을 종료값으로 두면 안전합니다. `approvals_by_approver.sql`은 종료 시각을 포함하는 `<=` 조건을 사용합니다.

`@start_kst`, `@end_kst`는 KST 기준 입력값입니다. SQL은 UTC로 저장된 `requested_at`과 비교할 때 9시간을 빼며, 출력 시각에는 9시간을 더해 KST로 표시합니다.

## `successful_dml_requests.sql`

`request_type = 'SQL_EXECUTION'`, `execution_status = 'SUCCESS'`인 Workflow와 해당 Workflow에 연결된 Query Audit 실행 로그를 결합합니다. Query 유형 코드가 `INSERT`(3), `UPDATE`(6), `DELETE`(7)인 행만 반환합니다. 하나의 Workflow에 여러 DML 문이 있으면 문장별로 여러 행이 나옵니다.

| 컬럼 | 설명 |
| --- | --- |
| `request_id` | Workflow 요청 ID |
| `request_uuid` | Workflow 요청 UUID |
| `title` | Workflow 제목 |
| `requested_at_kst` | Workflow 상신 시각(KST) |
| `requester_name` | 요청자 이름 |
| `requester_email` | 요청자 이메일 |
| `execution_status` | Workflow 실행 상태. 이 SQL에서는 `SUCCESS`만 대상 |
| `sub_query_index` | 한 요청 안에서 실행된 SQL 문장의 순번 |
| `executed_at_kst` | 해당 SQL 문장 실행 시각(KST) |
| `sql_type` | DML 유형(`INSERT`/`UPDATE`/`DELETE`) |
| `executed_query` | 실제 실행된 SQL 전문 |
| `processed_rows` | 처리된 행 수. 값이 없으면 `0` |
| `query_result` | Query Audit 실행 결과를 사람이 읽기 쉬운 상태로 변환한 값 |

## `ledger_dml_requests.sql`

`ledger = 1`인 SQL Workflow와 Query Audit 실행 로그를 결합합니다. Workflow의 전체 실행 성공 여부로 제한하지 않으므로, Ledger Workflow에서 기록된 DML 실행 행을 폭넓게 확인할 때 사용합니다. Query 유형 코드가 `INSERT`(3), `UPDATE`(6), `DELETE`(7)인 행만 반환합니다.

| 컬럼 | 설명 |
| --- | --- |
| `request_id` | Workflow 요청 ID |
| `request_uuid` | Workflow 요청 UUID |
| `title` | Workflow 제목 |
| `requested_at_kst` | Workflow 상신 시각(KST) |
| `requester_name` | 요청자 이름 |
| `requester_email` | 요청자 이메일 |
| `execution_status` | Workflow 실행 상태 |
| `sub_query_index` | 한 요청 안에서 실행된 SQL 문장의 순번 |
| `executed_at_kst` | 해당 SQL 문장 실행 시각(KST) |
| `sql_type` | DML 유형(`INSERT`/`UPDATE`/`DELETE`) |
| `executed_query` | 실제 실행된 SQL 전문 |
| `processed_rows` | 처리된 행 수. 값이 없으면 `0` |

## `approvals_by_approver.sql`

특정 승인자가 `WORKFLOW_APPROVED` 이벤트를 처리한 SQL Workflow 이력을 조회합니다. SQL 상단에서 승인자 이메일과 기간을 수정합니다.

```sql
SET @start_kst = '2024-01-01 00:00:00';
SET @end_kst = '2024-12-31 23:59:59';
SET @approver_email = 'approver@example.com';
```

승인자가 같은 Workflow에서 여러 승인 이벤트를 처리했다면 이벤트별로 여러 행이 나올 수 있습니다. 이 SQL은 승인 이력만 조회하며, 해당 Workflow에서 실행된 SQL 전문이나 DML 여부는 출력하지 않습니다.

| 컬럼 | 설명 |
| --- | --- |
| `requested_at_kst` | Workflow 상신 시각(KST) |
| `title` | Workflow 제목 |
| `requester_name` | 요청자 이름 |
| `requester_email` | 요청자 이메일 |
| `requester_login_id` | 요청자 Login ID |
| `approval_status` | Workflow의 현재 승인 상태 |
| `approver_name` | 승인 처리한 사용자 이름 |
| `approver_email` | 승인 처리한 사용자 이메일 |
| `approver_login_id` | 승인 처리한 사용자 Login ID |
| `approved_at_kst` | 승인 이벤트 처리 시각(KST) |
| `approval_comments` | 승인 처리 시 입력한 의견 |

## 유의 사항

- `executed_query`에는 민감한 조건값 또는 개인정보가 포함될 수 있습니다. 결과 파일의 열람·보관 권한을 관리하세요.
- DML 유형은 Query Audit의 `query_type` 코드에 의존합니다. 다른 DB 유형이나 제품 버전에서 코드 체계가 다르면 `CASE` 조건을 확인하세요.
- 승인 이력은 Log DB의 이벤트를 기준으로 하므로, Workflow의 현재 상태와 과거 승인 이벤트가 서로 다를 수 있습니다.
