# Query Audit 조회

성공한 Query Audit 실행 이력을 사용자, Connection, 권한, 실행 SQL, 처리량 및 Ledger 표시와 함께 상세 조회하는 SQL 모음입니다. 모든 SQL은 읽기 전용이며 Log DB(`querypie_log`)에 대한 조회 권한이 필요합니다.

## 파일 선택 및 실행 방법

| 파일 | 사용 목적 | 주요 입력 |
| --- | --- | --- |
| `query_audit_success_detail.sql` | 기간 내 성공한 Query Audit 상세 실행 이력 | 시작 시각, 종료 시각(KST) |

SQL 상단의 기간 변수를 수정한 뒤 실행합니다.

```sql
SET @start_kst = '2025-06-01 00:00:00';
SET @end_kst = '2025-06-20 00:00:00';
```

입력값은 KST 기준입니다. SQL은 `executed_at` 저장값과 비교할 때 9시간을 빼고, 출력할 때는 9시간을 더해 KST로 표시합니다. 시작 시각은 포함하고 종료 시각은 미포함이므로, 하루 전체를 조회하려면 종료값에 다음 날 00:00:00을 넣으세요.

예를 들어 2025-06-01 하루만 조회하려면 다음처럼 설정합니다.

```sql
SET @start_kst = '2025-06-01 00:00:00';
SET @end_kst = '2025-06-02 00:00:00';
```

## `query_audit_success_detail.sql`

`l_query_execution_logs.state = 1`인 성공 실행만 반환합니다. Query Audit 기본 로그에 상세 로그, DB Connection 스냅샷, 사용자 스냅샷, Connection 역할 스냅샷을 결합합니다. 로그 ID별 한 행을 보장하기 위해 `GROUP BY l.id`와 `ANY_VALUE()`를 사용합니다.

| 컬럼 | 설명 |
| --- | --- |
| `No` | Query Audit 로그 ID |
| `Executed At` | 실행 시각(KST) |
| `Result` | 실행 결과. 이 SQL은 성공(`SUCCESS`) 행만 조회 |
| `Name` | 실행 사용자 이름(사용자 스냅샷 기준) |
| `Email` | 실행 사용자 이메일(사용자 스냅샷 기준) |
| `Action Type` | 수행 동작 유형(접속, SQL 실행, 데이터 Export/Import, 복사 등) |
| `Connection Name` | 실행에 사용한 Connection 이름 |
| `Database Type` | 대상 DB 유형 |
| `Privilege Name` | 실행 시점에 적용된 Connection 역할 이름 |
| `Client IP` | 실행 클라이언트 IP 주소 |
| `Replication Type` | 대상 Connection의 복제 유형 |
| `DB Host` | 대상 DB 호스트 |
| `DB Name` | 대상 DB 이름 |
| `DB User` | 실제 DB 접속 사용자 |
| `Table(s)` | SQL에서 식별된 대상 테이블 이름 목록 |
| `SQL Type` | SQL 구문 유형(`Select`, `Insert`, `Update`, `Delete`, `DDL` 등) |
| `Query` | 실행한 SQL 전문 |
| `Time(ms)` | 실행 처리 시간(밀리초) |
| `Rows` | 처리된 레코드 수. 값이 없으면 빈 문자열 |
| `Data Size` | 처리된 데이터 크기. 값이 없으면 빈 문자열 |
| `Client Name` | 실행 클라이언트 이름. 값이 없으면 빈 문자열 |
| `Error Message` | 상세 로그의 오류 메시지. 성공 실행에서는 일반적으로 빈 값 |
| `Execution Reason` | 실행 사유 또는 작업 코멘트 |
| `Prevented` | 정책에 의해 차단되었는지 여부(`Not Prevented`/`Prevented`) |
| `Label` | Ledger 표시 여부(`Normal`/`Ledger`) |
| `Executed From` | 실행 유입 경로(Web Editor, Proxy, SQL Request, SQL Job, SQL Export Request 등) |

## 유의 사항

- 이 SQL은 실패·중지·차단된 Query Audit 행을 제외합니다. 전체 결과 상태가 필요하면 `WHERE l.state = 1` 조건을 조정하세요.
- `Query`, `Execution Reason`, `Table(s)`, 사용자·Connection 정보에는 민감한 정보가 포함될 수 있습니다. 추출 결과의 열람 및 보관 권한을 관리하세요.
- QueryPie Log DB의 `executed_at`은 UTC 저장값으로 처리하며, 이 SQL은 KST 입력값을 UTC로 변환해 비교하고 KST로 출력합니다.
