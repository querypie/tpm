# 접근 권한 조회

Connection별 역할 부여, 현재 접근 가능 사용자, 권한 부여 이력, Connection Owner를 조회하는 SQL 모음입니다. 모든 SQL은 App DB(`querypie`) 읽기 권한이 필요합니다.

## 파일 선택

| 파일 | 사용 목적 | 주요 입력 |
| --- | --- | --- |
| `role_grants_as_of_date.sql` | 특정 기준일에 특정 Connection에 유효한 역할 부여 현황 | 기준일, Connection 이름 |
| `connection_accessible_users.sql` | 모든 Connection에 현재 접근 가능한 사용자와 사용자 수 | 없음(현재 시각 기준) |
| `connection_privilege_grants.sql` | 기간 중 새로 부여된 Connection 권한의 상세 | 시작 시각, 종료 시각(KST) |
| `connection_owners.sql` | 모든 Connection의 Connection Owner 목록(사용자 이름을 한 셀에 묶음) | 없음 |
| `connection_owner_assignments.sql` | Connection Owner를 Connection·사용자 단위로 상세 조회 | 없음 |

## `role_grants_as_of_date.sql`

특정 날짜에 한 Connection에 유효한 역할 부여를 조회합니다. SQL 상단에서 아래 변수를 수정합니다.

```sql
SET @as_of_date = '2026-03-31';
SET @connection_name = CONVERT('connection-name' USING utf8mb4) COLLATE utf8mb4_general_ci;
```

삭제되지 않은 사용자와 역할 부여만 대상으로 하며, 부여일부터 만료일 사이에 기준일이 포함되는 권한을 출력합니다. 만료일이 없으면 무기한 권한으로 처리합니다.

기준일과 모든 시각 출력은 KST 기준입니다. SQL은 UTC 저장 시각을 KST 날짜로 변환해 기준일을 비교합니다.

`cluster_groups.name`이 `utf8mb4_general_ci`이고 접속 세션이 `utf8mb4_0900_ai_ci`인 환경에서는 Connection 이름 비교 시 collation 오류가 발생할 수 있습니다. SQL은 `@connection_name`을 `utf8mb4_general_ci`로 명시해 이 오류를 방지합니다. Connection 이름만 변경하고 `CONVERT` 및 `COLLATE` 부분은 유지하세요.

| 컬럼 | 설명 |
| --- | --- |
| `User Type` | 권한이 부여된 사용자 객체 유형 |
| `User Name` | 사용자 이름 |
| `Connection Name` | 대상 Connection 이름 |
| `DB Host` | 대상 DB 호스트 |
| `Replication Type` | DB 복제 유형. `MASTER`/`SLAVE`/`SINGLE`을 사람이 읽기 쉬운 값으로 변환 |
| `Role Name` | 부여된 Connection 역할 이름 |
| `Status` | SQL의 `enabled`/`expired` 상태 표현값 |
| `Granted At` | 권한 부여 시각(KST) |
| `Expiration At` | 권한 만료 시각(KST). 값이 없으면 무기한 |
| `Renewed At` | 권한 갱신 시각(KST) |
| `Last Access At` | 마지막 접근 시각(KST) |

## `connection_accessible_users.sql`

모든 활성 Connection별로 현재 접근 가능한 사용자 수와 사용자 목록을 조회합니다. 직접 사용자에게 부여된 권한뿐 아니라 사용자 그룹을 통해 부여된 권한도 포함하며, 중복 사용자는 한 번만 집계합니다.

현재 활성 권한은 삭제되지 않았고, 활성화되어 있으며, 만료되지 않았고, 만료 시각이 없거나 현재 시각보다 미래인 권한으로 판단합니다. 만료 시각이 UTC로 저장되므로 세션 시간대와 무관하게 `UTC_TIMESTAMP()`로 비교합니다. 사용자 목록이 길 수 있어 실행 시 `group_concat_max_len`을 1,000,000으로 설정합니다.

| 컬럼 | 설명 |
| --- | --- |
| `connection_uuid` | Connection UUID |
| `connection_name` | Connection 이름 |
| `assigned_user_count` | 현재 접근 가능한 고유 사용자 수 |
| `assigned_users` | `login_id (사용자명)` 형식으로 연결한 현재 접근 가능 사용자 목록 |

## `connection_privilege_grants.sql`

지정 기간에 부여된 Connection 권한을 상세하게 조회합니다. SQL 상단에서 기간을 수정합니다.

```sql
SET @start_kst = '2025-01-01 00:00:00';
SET @end_kst = '2025-12-31 00:00:00';
```

입력값은 KST 기준입니다. SQL은 UTC로 저장된 권한 부여 시각과 비교할 때 9시간을 빼며, 모든 권한 시각은 KST로 출력합니다. 시작일은 포함하고 종료일 다음 날 직전까지 포함합니다. 즉, 종료일 전체를 조회합니다.

`스키마 범위 (NULL=전체)` 컬럼은 Schema 권한이 활성화된 환경에서만 사용합니다. Schema 권한을 사용하지 않는 환경에서는 SQL의 `crm.schemas AS \`스키마 범위 (NULL=전체)\`,` 선택 항목을 제거한 뒤 실행하세요.

| 컬럼 | 설명 |
| --- | --- |
| `커넥션명` | Connection 이름 |
| `DB 유형` | Connection DB 유형 |
| `호스트` | DB 호스트 |
| `포트` | DB 포트 |
| `로그인 ID` | 권한이 부여된 사용자의 Login ID |
| `사용자명` | 권한이 부여된 사용자 이름 |
| `이메일` | 권한이 부여된 사용자 이메일 |
| `부서` | 권한이 부여된 사용자 부서 |
| `역할명` | 부여된 역할 이름 |
| `권한 DB 유형` | 역할이 적용되는 DB 벤더 유형 |
| `권한 목록 (DML/DCL/DDL)` | 역할에 설정된 권한 유형 목록 |
| `Can Import` | Import 허용 여부 (`Y`/`N`) |
| `Can Export` | Export 허용 여부 (`Y`/`N`) |
| `Can Copy to Clipboard` | Clipboard 복사 허용 여부 (`Y`/`N`) |
| `스키마 범위 (NULL=전체)` | 역할이 적용되는 Schema 범위. `NULL`이면 전체. Schema 권한을 사용하지 않는 환경에서는 SQL에서 이 컬럼을 제거 |
| `권한 부여일시` | 권한 부여 시각(KST) |
| `권한 만료일시 (NULL=무기한)` | 권한 만료 시각(KST). `NULL`이면 무기한 |
| `현재 상태` | 현재 활성 여부 (`활성`/`비활성`) |

## `connection_owners.sql`

모든 활성 Connection에 지정된 Connection Owner를 조회합니다. Connection Owner는 일반 Connection 역할 테이블에서 이름으로 찾는 역할이 아니라, QueryPie 코드의 사전 정의 역할(`PredefinedRole.CONNECTION_OWNER`)입니다. 따라서 SQL에 현재 제품의 사전 정의 UUID를 내장해 두었으며 별도 변수 입력은 필요하지 않습니다.

제품 버전에서 이 사전 정의 역할 UUID가 변경된 경우에만 SQL 상단 주석의 UUID를 새 값으로 바꾸세요. 현재 UUID는 `c3594b76-5d4e-11ec-b114-0ab3e84d3368`입니다.

| 컬럼 | 설명 |
| --- | --- |
| `등록된 DB명` | Connection 이름 |
| `등록된 Connection Owner` | Connection Owner 사용자 이름 목록. 여러 명이면 쉼표로 구분 |

## `connection_owner_assignments.sql`

Connection Owner를 찾기 위한 상세 조회입니다. Owner가 지정된 Connection만 반환하고, Connection마다 사용자 한 명당 한 행을 출력합니다. 사용자 식별자와 역할 배정 시각이 필요할 때 사용하세요. `connection_owners.sql`은 모든 Connection을 유지하면서 이름만 집계해 보는 용도입니다.

| 컬럼 | 설명 |
| --- | --- |
| `Connection UUID` | Connection UUID |
| `Connection Name` | Connection 이름 |
| `User UUID` | Connection Owner 사용자 UUID |
| `Login ID` | Connection Owner의 Login ID |
| `User Name` | Connection Owner 사용자 이름 |
| `Email` | Connection Owner 사용자 이메일 |
| `Assigned At` | 해당 사용자에게 Connection Owner 역할이 배정된 시각(KST) |

## 유의 사항

- 역할·사용자·Connection의 삭제 여부 및 활성 상태는 각 SQL의 조건에 따라 다르게 적용됩니다. 목적에 맞는 SQL을 선택한 뒤 조건을 변경하세요.
- 결과에는 사용자 이름, 이메일, 부서, 접근 권한 등 민감한 정보가 포함될 수 있으므로 추출 파일의 접근 권한을 관리하세요.
