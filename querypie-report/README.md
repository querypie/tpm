# QueryPie 감사·이력 조회 도구

이 디렉터리는 QueryPie의 Workflow SQL 실행 이력, Query Audit, Ledger 정책, 사용자·접근 권한·Activity Log 이력을 조회·추출하기 위한 독립 실행 도구와 SQL 모음입니다. 모든 SQL은 읽기 전용이며, 내부 시각은 UTC 저장값을 기준으로 KST 입력·출력으로 처리합니다.

## 디렉터리 안내

| 디렉터리 | 목적 | 시작 문서 |
| --- | --- | --- |
| [workflow_sql_audit_export](workflow_sql_audit_export/) | 승인·실행 완료된 SQL Workflow를 CSV로 추출하고 Query Audit, Ledger 정책, 선택적 DML Snapshot 데이터를 결합 | [README.md](workflow_sql_audit_export/README.md) |
| [ledger_workflow_dml_count](ledger_workflow_dml_count/) | 활성 Ledger 정책 테이블별 DML Query Audit 건수를 기간 단위로 집계 | [README.md](ledger_workflow_dml_count/README.md) |
| [user_history](user_history/) | 사용자 생성·삭제와 계정 잠김·해제·만료, 로그인 성공·실패 이력 조회 | [README.md](user_history/README.md) |
| [query_audit](query_audit/) | 성공한 Query Audit의 실행 SQL·Connection·권한·처리량 상세 조회 | [README.md](query_audit/README.md) |
| [workflow_sql_history](workflow_sql_history/) | 성공·Ledger DML Workflow 및 승인자 기준 SQL Workflow 이력 조회 | [README.md](workflow_sql_history/README.md) |
| [access_control](access_control/) | Connection 접근 사용자, 역할 부여, 권한 상세, Owner 조회 | [README.md](access_control/README.md) |
| [ledger_policy](ledger_policy/) | 모든 DB 유형의 활성 Ledger 정책 테이블 목록 조회 | [README.md](ledger_policy/README.md) |
| [activity_log](activity_log/) | Activity Log의 변경 전·후 값 조회 | [README.md](activity_log/README.md) |

## 빠른 선택

- 특정 기간의 SQL Workflow, 승인자, 실행 쿼리, Ledger 여부를 CSV로 받아야 하면 `workflow_sql_audit_export`를 사용합니다.
- Ledger 정책 테이블에 대해 실제 DML이 얼마나 수행됐는지 확인하려면 `ledger_workflow_dml_count`를 사용합니다.
- 사용자 계정 생성·삭제·잠김 관련 이력이나 로그인 성공·실패 이력을 확인하려면 `user_history`를 사용합니다.
- Query Audit 원본 상세가 필요하면 `query_audit`, Workflow DML/승인 이력은 `workflow_sql_history`를 사용합니다.
- Connection 권한은 `access_control`, 모든 DB 유형의 Ledger 정책 대상은 `ledger_policy`, 변경 전·후 Activity Log는 `activity_log`를 사용합니다.

## 공통 유의 사항

- 각 도구의 하위 README를 먼저 읽고, 기간·DB 연결 정보·출력 컬럼을 확인한 뒤 실행하세요.
- SQL은 App DB(`querypie`)와 Log DB(`querypie_log`)를 함께 조회할 수 있습니다. 실행 계정에는 필요한 읽기 권한이 있어야 합니다.
- SQL의 기간 변수는 특별한 설명이 없는 한 KST로 입력합니다. QueryPie 내부 시각은 UTC로 저장되므로, 각 하위 README의 KST 변환 규칙을 유지하세요.
- DB 접속 비밀번호는 파일이나 명령행에 기록하지 말고 환경변수 또는 안전한 인증 방식을 사용하세요.
- Workflow Snapshot 출력에는 변경 전·후의 민감한 값이 포함될 수 있으므로, 필요한 경우에만 옵션을 켜고 결과 파일의 접근 권한을 관리하세요.
