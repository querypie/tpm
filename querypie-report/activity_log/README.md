# Activity Log 변경 전·후 조회

- `activity_log_before_after.sql`: Activity Log의 `deltas` JSON을 펼쳐 변경 전·후 값을 조회합니다.

MySQL 8.0 이상의 `JSON_TABLE`을 사용합니다. SQL 상단의 기간 변수와 결과의 `action_at_kst`는 모두 KST 기준입니다. 선택 필터는 주석 처리된 조건에서 설정합니다. 변경 전·후 값은 민감할 수 있으므로 결과 파일 접근 권한을 관리하세요.

## 결과 컬럼

| 순서 | 컬럼 | 설명 |
| ---: | --- | --- |
| 1 | `event_id` | Activity Log ID |
| 2 | `event_uuid` | Activity Log UUID |
| 3 | `action_at_kst` | 이벤트 발생 시각(KST) |
| 4 | `event_type` | 이벤트 유형(`action_type`) |
| 5 | `target_type` | 변경 대상 유형 |
| 6 | `target_name` | 변경 대상 이름 |
| 7 | `target_uuid` | 변경 대상 UUID |
| 8 | `client_ip` | 이벤트를 발생시킨 클라이언트 IP |
| 9 | `actor_name` | 이벤트 수행자 이름 |
| 10 | `actor_email` | 이벤트 수행자 이메일 |
| 11 | `actor_dept` | 이벤트 수행자 부서 |
| 12 | `key` | 변경된 속성의 내부 키 |
| 13 | `label` | 변경된 속성의 표시 이름 |
| 14 | `before` | 변경 전 값 |
| 15 | `after` | 변경 후 값 |
| 16 | `has_changed` | 실제 값 변경 여부 (`1`/`0`) |
| 17 | `is_storable` | 해당 변경값의 저장 가능 여부 (`1`/`0`) |

`deltas` 배열의 항목마다 한 행이 생성됩니다. 따라서 하나의 Activity Log가 여러 속성을 변경한 경우 같은 `event_id`가 여러 행에 반복될 수 있습니다.
