# 사용자 이력 조회

사용자 생성·삭제, 계정 잠김·해제·만료 및 로그인 성공·실패 이력을 조회하는 SQL 모음입니다. 모든 SQL은 읽기 전용입니다.

## 파일 선택

| 파일 | 사용 목적 | 필요 DB | 주요 입력 |
| --- | --- | --- | --- |
| `user_history_1.sql` | 사용자 생성·삭제와 계정 잠김·해제·만료를 하나의 시간순 결과로 조회 | App DB, Log DB | 없음 |
| `user_login_success.sql` | 성공한 로그인 이력 상세 조회 | Log DB | 시작 시각, 종료 시각(KST) |
| `user_login_failure.sql` | 실패한 로그인 이력 조회 | Log DB | 시작 시각, 종료 시각(KST) |

## `user_history_1.sql`

App DB(`querypie`)의 현재 사용자 정보와 Log DB(`querypie_log`)의 Activity Log·User Auth Log를 결합해 주요 사용자 상태 변경 이력을 시간순으로 출력합니다.

### 포함 이벤트

| 원본 이벤트 | 출력 이벤트 | 출처 |
| --- | --- | --- |
| `USER_CREATED` | 사용자 생성 | Activity Log |
| `USER_DELETED` | 사용자 삭제 | Activity Log |
| `LOCKED` | 계정 잠김 | User Auth Log |
| `LOCKED_MANUALLY` | 계정 수동 잠김 | User Auth Log |
| `UNLOCK` | 잠김 해제 | User Auth Log |
| `EXPIRED` | 만료됨 | User Auth Log |

기간 조건이 없으므로 전체 이력을 반환합니다. 데이터가 많은 운영 환경에서는 두 CTE(`user_activity_logs`, `user_auth_logs`)의 `WHERE` 절에 기간 조건을 추가해 사용하세요.

| 컬럼 | 설명 |
| --- | --- |
| `시간` | 이벤트 발생 시각(KST) |
| `이벤트` | 사람이 읽기 쉬운 이벤트 이름 |
| `사용자 Id or Name` | 대상 사용자의 Login ID를 우선 사용하고, 없으면 이름 사용 |
| `행위자 Id` | 이벤트를 수행한 사용자의 Login ID |
| `사유` | 잠김·잠김 해제·만료 사유 또는 로그 메시지 |
| `사용자생성일` | 대상 사용자의 생성 시각(KST) |
| `마지막로그인` | 대상 사용자의 마지막 로그인 시각(KST) |
| `Unlock시간` | 대상 사용자의 잠김 해제 시각(KST) |

## `user_login_success.sql`

`action_type = 'LOGIN'` 및 `error = 0`인 성공 로그인 이력을 조회합니다. 입력 기간은 KST 기준이며, SQL은 UTC 로그 시각과 비교하기 위해 9시간을 빼서 비교합니다. 시작 시각은 포함하고 종료 시각은 미포함입니다.

```sql
SET @start_kst = '2025-01-01 00:00:00';
SET @end_kst = '2025-02-01 00:00:00';
```

`SELECT *`를 사용하지 않고 현재 QueryPie의 User Auth Log 컬럼을 명시적으로 선택하도록 정리했습니다. 제품 버전에서 Log DB 스키마가 달라진 경우에는 컬럼 목록을 확인하세요.

| 컬럼 | 설명 |
| --- | --- |
| `id` | User Auth Log ID |
| `hash` | 로그 무결성 검증용 해시 |
| `user_id` | 로그인 대상 사용자의 내부 ID |
| `user_login_id` | 로그인 대상 사용자의 Login ID |
| `user_name` | 로그인 대상 사용자 이름 |
| `user_email` | 로그인 대상 사용자 이메일 |
| `action_type` | 인증 동작 유형. 이 SQL에서는 `LOGIN` |
| `acted_at_kst` | 로그인 처리 시각(KST) |
| `error` | 인증 실패 여부. 이 SQL에서는 `0` |
| `message` | 인증 처리 메시지 |
| `client_ip` | 로그인 클라이언트 IP 주소 |
| `host_name` | 로그인 클라이언트 호스트 이름 |
| `actor_user_id` | 행위자 사용자 내부 ID. 일반 로그인에서는 비어 있을 수 있음 |
| `actor_user_name` | 행위자 사용자 이름. 일반 로그인에서는 비어 있을 수 있음 |
| `created_by` | 로그 생성 주체의 내부 ID |
| `created_at_kst` | 로그 레코드 생성 시각(KST) |

## `user_login_failure.sql`

`action_type = 'LOGIN'` 및 `error = 1`인 로그인 실패 이력을 조회합니다. `created_at`을 기간 조건으로 사용하며, 시작 시각은 포함하고 종료 시각은 미포함입니다.

```sql
SET @start_kst = '2025-01-01 00:00:00';
SET @end_kst = '2025-02-01 00:00:00';
```

입력 시각은 KST 기준이며, SQL은 UTC로 저장된 `created_at`과 비교할 때 9시간을 뺍니다. `acted_at`은 KST로 변환해 출력합니다. 별도 `ORDER BY`가 없으므로 결과 순서가 필요하면 `ORDER BY acted_at` 등을 추가하세요.

| 컬럼 | 설명 |
| --- | --- |
| `acted_at_kst` | 로그인 시도 처리 시각(KST) |
| `user_login_id` | 로그인 시도한 Login ID |
| `user_name` | 로그인 시도 사용자 이름 |
| `user_email` | 로그인 시도 사용자 이메일 |
| `client_ip` | 로그인 시도 클라이언트 IP 주소 |
| `host_name` | 로그인 시도 클라이언트 호스트 이름 |
| `message` | 로그인 실패 사유 또는 인증 메시지 |

## 유의 사항

- 결과에는 사용자 식별자, 이메일, IP 주소, 인증 관련 메시지가 포함될 수 있습니다. 추출 파일의 열람·보관 권한을 관리하세요.
- 삭제된 사용자는 App DB의 `users` 레코드가 없어도 로그에 남은 이름·Login ID 범위에서 표시됩니다.
- 모든 SQL은 UTC 저장 시각을 기준으로 KST 입력값을 변환해 비교하며, 출력 시각도 KST로 표시합니다.
