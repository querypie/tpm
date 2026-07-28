# Ledger 테이블 DML 건수 조회

[ledger_table_dml_count.sql](ledger_table_dml_count.sql)은 활성 Ledger 정책 테이블별로 지정 기간에 수행된 DML Query Audit 건수를 조회합니다.

## 대상 데이터

- App DB (`querypie`)
  - `ledger_policy_tables`, `ledger_policies`, `policies`
  - `cluster_groups`, `workflow_rules`
- Log DB (`querypie_log`)
  - `l_query_execution_logs`
  - `l_db_connection_snapshots`
  - `l_query_execution_log_details`

조회 대상은 숨김 처리되지 않았고(`hidden = 0`), Ledger로 기록됐으며(`ledger = 1`), 성공 상태(`state = 1`)이고, 대상 객체가 있는 Query Audit입니다.

## 기간 설정

SQL 상단의 변수를 KST 기준으로 수정합니다.

```sql
SET @start_kst = '2025-01-01 00:00:00';
SET @end_kst   = '2026-01-01 00:00:00';
SET @tz_offset_hour = 9;
```

- 시작 시각은 포함됩니다.
- 종료 시각은 포함되지 않습니다.
- Query Audit의 UTC `executed_at`과 비교할 때 KST 9시간을 차감합니다.

## 실행 예시

App DB와 Log DB를 모두 조회할 수 있는 MySQL 계정으로 실행합니다.

```bash
mysql -h <host> -P <port> -u <user> -p < ledger_table_dml_count.sql
```

데이터가 큰 기간에는 대상 객체 문자열을 재귀적으로 분리하므로, 기간을 나누어 실행하는 것을 권장합니다.

## 조회 방식

1. 활성 Ledger 정책에서 Connection / Database / Schema / Table 목록을 읽습니다.
2. 테이블 표기 방식 차이를 고려해 `table`, `database.table`, `schema.table`, `database.schema.table` 후보를 만듭니다.
3. Ledger Query Audit의 `target_object_names`를 테이블 단위로 분리하고 식별자 따옴표를 제거합니다.
4. Connection Group, 대상 테이블, 필요한 경우 Database까지 일치시키고 DML Query Audit을 집계합니다.

집계하는 DML `query_type`은 `3, 4, 5, 6, 7, 8`입니다. Query Audit 한 건은 같은 Ledger 테이블에 한 번만 집계됩니다.

## 결과 컬럼

| 컬럼 | 설명 |
| --- | --- |
| `Connection` | Ledger 정책이 적용된 Connection 이름 |
| `Database` | Ledger 정책 Database 이름 |
| `Schema` | Ledger 정책 Schema 이름 |
| `Table` | Ledger 정책 테이블 이름 |
| `RuleName` | 연결된 Workflow Rule 이름 |
| `DML 개수` | 기간 내 해당 Ledger 테이블에 매칭된 DML Query Audit 건수 |

Ledger 정책 테이블은 조회 기간에 매칭되는 DML이 없어도 결과에 포함되며, 이 경우 `DML 개수`는 `0`입니다.
