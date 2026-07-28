# Workflow SQL Audit Export

승인·실행이 완료된 SQL Workflow 요청을 CSV로 추출하고, Query Audit·Ledger 정책 정보를 결합해 감사용 CSV를 생성하는 Python 2.7 호환 도구입니다.

## 구성

- `export_workflow_sql_requests.py`: Workflow 요청, 결제선, 승인자 및 승인 일시를 원본 CSV로 추출합니다.
- `enrich_workflow_sql_audit.py`: Query Audit의 실행 쿼리·대상 테이블과 Ledger 정책 테이블 매칭 결과를 최종 CSV에 추가합니다.
- `export_workflow_sql_audit.sh`: 위 두 단계를 순서대로 실행합니다.

## 사전 조건

- Python 2.7.7 이상 (권장: Python 2.7.18)
- MySQL 접근 권한
  - App DB: Workflow, 결제선, Ledger 정책 조회
  - Log DB: Query Audit 조회
  - Snapshot DB: 변경 전·후 데이터 옵션 사용 시에만 필요
- `PyMySQL` 또는 `mysql-connector-python`
  - 네트워크가 제한된 환경에서는 `vendor-python2` 디렉터리에 사전 다운로드한 패키지를 두고 실행합니다.

### Python DB 드라이버 설치

권장 방식은 Python 2.7용 PyMySQL을 프로젝트의 `vendor-python2`에 설치하는 것입니다.

```bash
cd workflow_sql_audit_export
python2.7 -m pip install --target vendor-python2 'PyMySQL<1.0'
```

이 명령을 실행하면 셸 스크립트가 `vendor-python2`를 자동으로 사용합니다. 이 방식을 사용하지 않는다면, 실행 환경의 Python 2.7에 PyMySQL 또는 `mysql-connector-python`을 설치해야 합니다.

환경에 따라 DB 연결 과정에서 `cryptography` 관련 오류가 발생할 수 있습니다. 이 경우 Python 2.7과 호환되는 `cryptography` 패키지를 설치하거나, QueryPie Agent를 통해 DB에 연결하면 문제 없이 처리할 수 있습니다.

## 실행

실행 스크립트가 있는 디렉터리에서 실행합니다.

```bash
cd workflow_sql_audit_export

export QUERYPIE_DB_PASSWORD='앱 DB 비밀번호'
./export_workflow_sql_audit.sh
```

기본 추출 기간은 셸 스크립트의 `FROM`, `TO` 값입니다. 기간·결제선·출력 경로를 바꾸려면 [export_workflow_sql_audit.sh](export_workflow_sql_audit.sh)의 상단 변수를 수정합니다.

### 연결 환경변수

App DB 설정은 필수 비밀번호 외에는 기본값을 사용합니다.

```bash
export QUERYPIE_DB_HOST='127.0.0.1'
export QUERYPIE_DB_PORT='3306'
export QUERYPIE_DB_USER='querypie'
export QUERYPIE_DB_PASSWORD='...'
export QUERYPIE_DB_NAME='querypie'
```

Log DB와 Snapshot DB가 분리되어 있으면 아래 값을 추가로 설정합니다. 설정하지 않으면 Log DB는 App DB 설정을, Snapshot DB는 Log DB 설정을 상속합니다.

```bash
export QUERYPIE_LOG_DB_HOST='...'
export QUERYPIE_LOG_DB_PORT='3306'
export QUERYPIE_LOG_DB_USER='...'
export QUERYPIE_LOG_DB_PASSWORD='...'
export QUERYPIE_LOG_DB_NAME='querypie_log'

export QUERYPIE_SNAPSHOT_DB_HOST='...'
export QUERYPIE_SNAPSHOT_DB_PORT='3306'
export QUERYPIE_SNAPSHOT_DB_USER='...'
export QUERYPIE_SNAPSHOT_DB_PASSWORD='...'
export QUERYPIE_SNAPSHOT_DB_NAME='querypie_snapshot'
```

비밀번호는 스크립트나 명령행에 기록하지 말고 환경변수로만 제공합니다.

### 결제선 필터

기본값은 모든 결제선을 추출합니다. 특정 결제선만 추출하려면 `export_workflow_sql_audit.sh`의 `APPROVAL_RULE_NAMES`에 쉼표로 구분한 이름을 넣습니다.

```bash
APPROVAL_RULE_NAMES="운영 결제선,보안 결제선"
```

직접 Python 스크립트를 실행할 때는 아래처럼 지정할 수 있습니다.

```bash
python2.7 export_workflow_sql_requests.py \
  --output workflows/workflow.csv \
  --from-kst '2026-07-01 00:00:00' \
  --to-kst '2026-08-01 00:00:00' \
  --approval-rule-name '운영 결제선,보안 결제선'
```

### 변경 전·후 데이터 옵션

기본 실행은 변경 전·후 DML Snapshot 데이터를 조회하지 않으며 Snapshot DB에도 연결하지 않습니다. 필요한 경우에만 다음 값을 설정합니다.

```bash
INCLUDE_DML_SNAPSHOTS=true ./export_workflow_sql_audit.sh
```

옵션을 켜면 최종 CSV에 `변경전데이터`, `변경후데이터` 컬럼이 추가됩니다. 대용량 데이터는 `--inline-threshold-bytes`와 `--large-file-mode` 설정의 영향을 받습니다.

## 생성 파일

기본 실행은 다음 경로에 파일을 생성합니다.

```text
workflows/
  workflow.001.csv                # Workflow 원본 추출 결과
  result/
    output_workflow.001.csv       # Query Audit·Ledger 매칭이 추가된 최종 결과
  progress/                       # 파일별 처리 로그
```

`--rows-per-file` 기본값에 따라 원본 CSV가 여러 파일로 나뉠 수 있습니다.

## 최종 CSV 데이터

기본 출력 컬럼은 아래 순서입니다. `INCLUDE_DML_SNAPSHOTS=true`일 때만 `변경전데이터`, `변경후데이터`가 `요청자` 뒤에 추가됩니다.

| 순서 | 컬럼 | 설명 |
| ---: | --- | --- |
| 1 | `workflow 상신일` | Workflow 요청 시간(KST) |
| 2 | `사후결제여부` | Workflow의 `urgent` 플래그를 `Y`/`N`으로 표시 |
| 3 | `변경수행일` | SQL 실행 완료 시각(KST) |
| 4 | `요청자` | Workflow 요청자 |
| 조건부 | `변경전데이터` | DML Snapshot 변경 전 데이터. Snapshot 옵션 사용 시에만 추가 |
| 조건부 | `변경후데이터` | DML Snapshot 변경 후 데이터. Snapshot 옵션 사용 시에만 추가 |
| 5 | `변경제목` | Workflow 요청 제목 |
| 6 | `변경사유` | Workflow 요청 사유 또는 설명 |
| 7 | `Connection/DB명` | SQL 실행 대상 Connection과 Database |
| 8 | `테이블명` | Query Audit이 기록한 대상 테이블 |
| 9 | `Ledger 테이블 여부` | 대상 테이블의 활성 Ledger 정책 테이블 매칭 여부 |
| 10 | `매칭 Ledger 테이블` | 매칭된 Ledger 정책의 Database/Schema/Table |
| 11 | `Ledger 테이블 등록일` | 매칭된 Ledger 정책 테이블의 등록 시각(KST) |
| 12 | `Ledger 테이블 수정일` | 매칭된 Ledger 정책 테이블의 마지막 수정 시각(KST) |
| 13 | `컬럼명` | Snapshot 비교로 식별한 변경 컬럼 |
| 14 | `대상건수` | Query Audit의 처리 건수 또는 Snapshot에서 계산한 건수 |
| 15 | `쿼리실행시간` | Query Audit의 SQL 실행 시각(KST) |
| 16 | `수행쿼리` | Query Audit의 원본 SQL |
| 17 | `수행자` | SQL 실행 담당자 |
| 18 | `1차승인자` | 1차 결제 승인자 |
| 19 | `1차승인일시` | 1차 결제 처리 시각(KST) |
| 20 | `2차승인자` | 2차 결제 승인자 |
| 21 | `2차승인일시` | 2차 결제 처리 시각(KST) |
| 22 | `3차승인자` | 3차 결제 승인자 |
| 23 | `3차승인일시` | 3차 결제 처리 시각(KST) |
| 24 | `4차승인자` | 4차 결제 승인자 |
| 25 | `4차승인일시` | 4차 결제 처리 시각(KST) |
| 26 | `변경요청근거(관리툴링크)` | 요청 사유에서 찾은 URL 또는 Jira 이슈 키. Jira 키는 URL로 변환하지 않음 |
| 27 | `Workflow Ledger 여부` | 개별 Workflow Request의 `ledger` 플래그 (`Y`/`N`) |
| 28 | `결제선 Ledger 여부` | 적용된 Workflow Rule의 `ledger` 플래그 (`Y`/`N`) |
| 29 | `Ledger` | 적용된 결제선 이름 |
| 30 | `workflow_uuid` | Workflow Request UUID |
| 31 | `workflow_id` | Workflow Request ID |

## 유의 사항

- 시간 조건 입력은 KST이며, DB의 UTC 시간과 비교할 때 스크립트가 변환합니다.
- 조회 대상은 `SQL_EXECUTION`, 승인 상태 `APPROVED`, 실행 상태 `SUCCESS`인 Workflow 요청입니다.
- Query Audit 대상 테이블이 여러 개면 Ledger 매칭 값은 `테이블명: 값` 형태로 함께 표시될 수 있습니다.
- Snapshot 데이터에는 민감한 변경 전·후 값이 포함될 수 있으므로 필요한 경우에만 옵션을 켜고, 생성된 CSV의 접근 권한을 관리하세요.
