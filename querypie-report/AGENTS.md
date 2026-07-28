# 작업 지침

이 저장소는 QueryPie 감사·이력 데이터를 조회하거나 CSV로 추출하기 위한 SQL과 Python 2.7 호환 도구를 포함합니다. SQL은 모두 읽기 전용 조회 도구입니다.

## 데이터 추출 전 확인

1. 사용자의 요청에 맞는 하위 디렉터리를 선택합니다.
2. **반드시 해당 디렉터리의 `README.md`를 먼저 읽습니다.** README에는 조회 목적, 필요한 DB 권한·환경변수, 기간 설정, 실행 방법, 출력 컬럼과 민감 데이터 유의 사항이 있습니다.
3. README의 설명과 SQL/스크립트의 실제 조건이 일치하는지 확인한 뒤 필요한 데이터만 추출합니다.

## 디렉터리별 라우팅

| 요청 유형 | 사용할 디렉터리 |
| --- | --- |
| Workflow SQL, 승인선, Query Audit, Ledger 매칭, DML Snapshot | `workflow_sql_audit_export/` |
| Ledger 정책 테이블별 DML 건수 | `ledger_workflow_dml_count/` |
| 사용자 생성·삭제·잠김·해제·만료 또는 로그인 성공·실패 이력 | `user_history/` |
| 성공 Query Audit 상세 | `query_audit/` |
| 성공·Ledger DML Workflow 또는 승인자별 Workflow 이력 | `workflow_sql_history/` |
| Connection 접근 사용자·역할·권한·Owner | `access_control/` |
| 모든 DB 유형의 Ledger 정책 대상 테이블 | `ledger_policy/` |
| Activity Log의 변경 전·후 값 | `activity_log/` |

## 시간대 원칙

- QueryPie 내부의 시각 컬럼은 UTC로 저장된다는 전제로 SQL을 작성합니다.
- 기간을 입력받는 SQL은 변수명을 `*_kst`로 두고, 비교할 때 KST 입력값에서 9시간을 빼 UTC 저장값과 비교합니다.
- 시각을 출력하는 SQL은 UTC 저장값에 9시간을 더하고, 가능하면 컬럼명에 `_kst`를 붙이거나 README에 KST임을 명시합니다.
- 현재 시각과 UTC 저장 만료 시각을 비교할 때는 세션 시간대에 의존하는 `NOW()` 대신 `UTC_TIMESTAMP()`를 사용합니다.
- 날짜 단위 기준일은 UTC 날짜가 아니라 KST로 변환한 날짜를 기준으로 판정합니다.

## 실행 원칙

- 조회 조건(특히 기간과 대상)을 먼저 확인하고, 요청 범위를 넘는 데이터를 추출하지 않습니다.
- DB 접속 정보와 비밀번호는 환경변수 또는 안전한 인증 방법으로만 제공합니다. 코드·README·명령 기록에 비밀번호를 추가하지 않습니다.
- SQL과 스크립트는 읽기 전용 조회 용도로 사용합니다. `INSERT`, `UPDATE`, `DELETE`, `DROP` 등 변경 작업은 사용자의 명시적 요청 없이는 수행하지 않습니다.
- Workflow Snapshot 데이터는 민감할 수 있으므로, `INCLUDE_DML_SNAPSHOTS=true`는 사용자가 명시적으로 필요하다고 한 경우에만 사용합니다.
- SQL을 실행하기 전에는 대상 기간, Connection·사용자 등 범위와 KST 입력값을 확인합니다.

## 문서 유지

- SQL 또는 스크립트의 입력, 실행 방법, 출력 컬럼 또는 시간대 처리를 변경하면 같은 디렉터리의 `README.md`도 함께 갱신합니다.
- 새 조회 도구를 추가하면 상위 `README.md`의 디렉터리 안내와 이 파일의 라우팅 표도 갱신합니다.
