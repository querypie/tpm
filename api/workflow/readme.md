# QueryPie Workflow Automation

## 개요

QueryPie Workflow Automation은 QueryPie의 SQL 실행 요청(SQL Request) 프로세스를 완전 자동화하는 Python 스크립트입니다. 이 스크립트는 SQL 요청 상신부터 다단계 승인, 실행까지의 전체 워크플로우를 자동으로 처리합니다.

## 주요 특징

- **자동화된 워크플로우**: SQL 요청 생성부터 실행까지 전 과정 자동화
- **다단계 승인 지원**: Rule 기반의 복잡한 승인 프로세스 자동 처리
- **리소스 선택**: 설정된 우선순위에 따른 Connection 및 Database 자동 선택
- **에러 처리**: 재시도 로직과 상세한 에러 메시지 제공
- **상세한 로깅**: 실행 과정의 모든 단계를 추적 가능한 로그로 기록

## 스크립트 구조

### 파일 구성

```
├── workflow.py     # 메인 실행 스크립트
├── config.py       # 설정 파일
└── paste.txt       # API 응답 샘플 데이터
```

### 주요 모듈

#### `workflow.py` - 메인 실행 스크립트
- **API 통신 함수들**: QueryPie API와의 모든 통신 담당
- **워크플로우 로직**: SQL Request Workflow의 전체 생명주기 관리
- **승인 처리**: Rule 기반 다단계 승인 자동화
- **에러 처리**: 재시도 로직과 예외 처리

#### `config.py` - 설정 파일
- **API 설정**: 기본 URL, 토큰, 타임아웃 등
- **사용자 설정**: 요청자 정보
- **워크플로우 설정**: 승인 조건, 우선순위 등
- **SQL 요청 기본값**: 쿼리, 제목, 날짜 등
- **Rule 기반 승인 설정**: 승인 단계별 댓글 및 지연 시간

## 주요 기능

### 1. 사용자 식별 및 인증
```python
def identify_user(login_id=None)
```
- 로그인 ID를 통해 사용자 UUID 조회
- API 토큰 기반 인증 처리

### 2. 승인 규칙 관리
```python
def fetch_approval_rules(request_type=None)
def fetch_approval_rule_detail(rule_uuid)
```
- SQL_EXECUTION 타입의 승인 규칙 조회
- 다단계 승인 구조 분석 및 처리

### 3. 리소스 자동 선택
```python
def select_connection(connections)
def select_database(database_names)
```
- 설정된 우선순위에 따른 Connection 자동 선택
- 사용 가능한 Database 목록에서 최적 선택

### 4. Rule 기반 승인 단계 생성
```python
def create_approval_steps_from_rule(rule_detail)
def get_approval_step_assignees_from_rule(rule_detail)
```
- Approval Rule에서 승인 단계 자동 생성
- 각 단계별 승인자 정보 추출 및 구성

### 5. 다단계 승인 자동화
```python
def approve_sql_request_with_rule(workflow_uuid, rule_detail)
```
- Rule에 정의된 승인 단계별 자동 처리
- 각 단계별 승인자 자동 식별 및 승인 실행

### 6. SQL Reqeust 실행
```python
def execute_sql_request(workflow_uuid, user_uuid)
```
- 승인 완료된 SQL Request Workflow 자동 실행
- Rule에서 정의된 실행 담당자 자동 선택

## API 명세

### 기본 정보
- **Base URL**: `{QUERYPIE_WEB_URL}/api/external/v2`
- **인증**: Bearer Token 방식
- **Content-Type**: `application/json`

### 주요 API 엔드포인트

#### 1. 사용자 식별
```
GET /users/identify?loginId={loginId}
```
**응답 예시:**
```json
{
  "status": "FOUND",
  "users": [
    {
      "uuid": "d8665fba-8080-11eb-a305-0a789f7c7580",
      "name": "Admin",
      "loginId": "admin@querypie.com",
      "email": "qp-admin"
    }
  ]
}
```

#### 2. Approval Rules 조회
```
GET /workflows/approval-rules?requestType=SQL_EXECUTION
```
**응답 예시:**
```json
{
  "list": [
    {
      "uuid": "b387c4c0-bbf2-11ed-9e22-0242ac110002",
      "name": "Default (No Rule)",
      "requestType": "SQL_EXECUTION",
      "createdAt": "2024-11-09T10:53:49.000Z",
      "updatedAt": "2025-05-22T07:41:04.572Z"
    }
  ],
  "page": {
    "currentPage": 0,
    "pageSize": 50,
    "totalPages": 1,
    "totalElements": 1
  }
}
```

#### 3. Approval Rule 상세 조회
```
GET /approval-rules/{ruleUuid}
```
**응답 예시:**
```json
{
  "uuid": "b387c4c0-bbf2-11ed-9e22-0242ac110002",
  "name": "Default (No Rule)",
  "requestType": "SQL_EXECUTION",
  "approvalSteps": [
    {
      "stepApproveCondition": "ANY",
      "ruleAssignees": [
        {
          "uuid": "2c33630e-a8a7-4552-a1dc-8d77d6c29f6b",
          "name": "elon"
        }
      ]
    }
  ],
  "executionAssignees": [
    {
      "uuid": "2c33630e-a8a7-4552-a1dc-8d77d6c29f6b",
      "name": "elon"
    }
  ]
}
```

#### 4. 접근 가능한 Connection 조회
```
GET /workflows/requests/accessible-connections?userUuid={userUuid}
```
**응답 예시:**
```json
[
  {
    "uuid": "d532200c-d586-47f4-9b58-95258a93bf0a",
    "name": "querypie-metadb",
    "type": "MySQL",
    "clusters": [
      {
        "uuid": "9f9615c7-d1f2-47f0-8344-2d81b4934ddc",
        "host": "172.31.7.229",
        "port": "3306",
        "replicationType": "SINGLE"
      }
    ]
  }
]
```

#### 5. Database 이름 목록 조회
```
GET /dac/connections/{connectionUuid}/clusters/{clusterUuid}/database-names?userUuid={userUuid}
```
**응답 예시:**
```json
{
  "databaseNames": ["querypie", "information_schema", "mysql"]
}
```

#### 6. SQL Request Workflow 생성
```
POST /workflows/sql-request
```
**요청 본문:**
```json
{
  "requesterUuid": "d8665fba-8080-11eb-a305-0a789f7c7580",
  "ruleUuid": "b387c4c0-bbf2-11ed-9e22-0242ac110002",
  "clusterUuid": "9f9615c7-d1f2-47f0-8344-2d81b4934ddc",
  "databaseName": "querypie",
  "content": "SELECT 1;",
  "title": "SQL Request Submit API Test",
  "comments": "API Test",
  "targetDate": "2025-05-22",
  "expirationDate": "2025-05-30",
  "urgent": false,
  "approvalSteps": [
    {
      "assignees": ["2c33630e-a8a7-4552-a1dc-8d77d6c29f6b"],
      "stepApproveCondition": "ANY"
    },
    {
      "assignees": ["afaec765-c8b7-4033-a719-3b0a086def2f"],
      "stepApproveCondition": "ANY"
    }
  ]
}
```

#### 7. 승인 처리
```
POST /workflows/{workflowUuid}/approve
```
**요청 본문:**
```json
{
  "userUuid": "2c33630e-a8a7-4552-a1dc-8d77d6c29f6b",
  "comments": "승인 완료"
}
```

#### 8. SQL Request 실행
```
POST /workflows/sql-request/{workflowUuid}/execute
```
**요청 본문:**
```json
{
  "userUuid": "2c33630e-a8a7-4552-a1dc-8d77d6c29f6b"
}
```

## 설정 방법

### 1. 기본 설정 (`config.py`)

#### API 설정
```python
API_CONFIG = {
    "base_url": "{QUERYPIE_WEB_URL}/api/external/v2",
    "api_token": "your-api-token-here",
    "timeout": 30
}
```

#### 사용자 설정
```python
USER_CONFIG = {
    "login_id": "your-login-id"
}
```

#### 워크플로우 설정
```python
WORKFLOW_CONFIG = {
    "request_type": "SQL_EXECUTION",
    "use_rule_based_approval": True,
    "approval_step_condition": "ANY",
    "approval_comments": "승인 완료",
    "urgent": False
}
```

#### Connection 및 Database 우선순위
```python
CONNECTION_CONFIG = {
    "preferred_connection_name": "querypie-metadb",
    "preferred_connection_type": "MySQL",
    "preferred_database": "querypie",
    "fallback_to_first": True
}
```

#### SQL 요청 기본값
```python
SQL_REQUEST_DEFAULTS = {
    "query": "SELECT 1;",
    "title": "SQL Request Submit API Test",
    "comments": "API Test",
    "target_date": "2025-05-22",
    "expiration_date": "2025-05-30"
}
```

#### Rule 기반 승인 설정
```python
RULE_BASED_APPROVAL_CONFIG = {
    "approval_delay": 1,  # 각 승인 단계 사이의 대기 시간 (초)
    "step_comments": {
        "step_1": "1차 승인 완료",
        "step_2": "2차 승인 완료",
        "default": "Rule 기반 자동 승인"
    }
}
```

#### 에러 처리 설정
```python
ERROR_CONFIG = {
    "retry_count": 3,       # 재시도 횟수
    "retry_delay": 1        # 재시도 간격 (초)
}
```

### 2. 로깅 설정
```python
LOGGING_CONFIG = {
    "verbose": True,        # 상세 로그 출력
    "show_response": False  # API 응답 내용 출력
}
```

## 사용 방법

### 1. 기본 실행
```bash
python workflow.py
```

### 2. 실행 프로세스
스크립트는 다음 순서로 실행됩니다:

1. **워크플로우 초기 설정** (`setup_workflow`)
    - 사용자 식별: 설정된 로그인 ID로 사용자 UUID 조회
    - Approval Rules 조회: SQL_EXECUTION 타입의 승인 규칙 선택
    - Rule 상세 정보 조회: 승인 단계 및 실행자 정보 확인

2. **연결 및 데이터베이스 설정** (`setup_connection`)
    - 접근 가능한 Connection 중 우선순위에 따라 선택
    - 선택된 Connection의 Database 목록에서 선택

3. **SQL Request 생성 및 상신** (`create_and_submit_request`)
    - Rule에서 승인 단계 자동 생성
    - 설정된 기본값으로 SQL 요청 상신

4. **승인 워크플로우 처리** (`process_approval_workflow`)
    - Rule에 정의된 승인 단계별로 순차 승인
    - 각 단계별 승인자 자동 식별 및 실행

5. **SQL Request 실행** (`execute_workflow`)
    - Rule에서 정의된 실행자로 SQL 자동 실행

### 3. 실행 결과 예시
```
[INFO] Starting QueryPie Workflow...
[INFO] User UUID: d8665fba-8080-11eb-a305-0a789f7c7580
[INFO] Selected Approval Rule UUID: b387c4c0-bbf2-11ed-9e22-0242ac110002
[INFO] Approval Rule Name: Default (No Rule)
[INFO] Fetching approval rule details...
[INFO] Rule has 2 approval step(s)
[INFO] Selected Connection: querypie-metadb (MySQL)
[INFO] Connection UUID: d532200c-d586-47f4-9b58-95258a93bf0a
[INFO] Cluster UUID: 9f9615c7-d1f2-47f0-8344-2d81b4934ddc
[INFO] Available Databases: ['querypie', 'information_schema', 'mysql']
[INFO] Selected Database: querypie
[INFO] Found 2 approval step(s) in rule
[INFO] Step 1: ['elon'] (Condition: ANY)
[INFO] Step 2: ['dba'] (Condition: ANY)
[INFO] Created 2 approval step(s) from rule
[INFO] Creating SQL Request...
[INFO] SQL Request created successfully!
[INFO] Workflow UUID: 92c4e575-8979-40c5-9a2d-f651e21a6ea0
[INFO] Starting rule-based approval process...
[INFO] Processing Step 1...
[INFO] Approving Step 1 with user: elon (UUID: 2c33630e-a8a7-4552-a1dc-8d77d6c29f6b)
[INFO] Step 1 completed by elon
[INFO] Remaining Steps: 1
[INFO] Processing Step 2...
[INFO] Approving Step 2 with user: dba (UUID: afaec765-c8b7-4033-a719-3b0a086def2f)
[INFO] Step 2 completed by dba
[INFO] All approval steps completed!
[INFO] Rule-based approval process completed!
[INFO] - Step 1: Approved by elon
[INFO] - Step 2: Approved by dba
[INFO] Executing SQL Request...
[INFO] Execution assignees from rule: ['elon']
[INFO] Using rule-defined executor: elon
[INFO] Execution completed successfully by elon!
[INFO] Workflow completed successfully!
```

## 고급 기능

### 1. 모듈화된 구조
각 단계별로 독립적인 함수로 구성되어 있어 개별 테스트 및 커스터마이징이 가능합니다:

```python
# 개별 단계 실행 예시
user_uuid, approval_rule_uuid, rule_detail = setup_workflow()
connection_uuid, cluster_uuid, selected_database = setup_connection(user_uuid)
workflow_uuid = create_and_submit_request(user_uuid, approval_rule_uuid, rule_detail, cluster_uuid, selected_database)
```

### 2. Rule 기반 승인 시스템
```python
# Rule에서 승인 단계 자동 생성
approval_steps = create_approval_steps_from_rule(rule_detail)

# Rule 기반 자동 승인 처리
approval_results = approve_sql_request_with_rule(workflow_uuid, rule_detail)
```

### 3. 상세한 로깅 및 모니터링
```python
# 각 승인 단계별 상세 로그
def approve_single_step(workflow_uuid, step_info, step_index):
    logger.info(f"Processing {step_info['step_name']}...")
    logger.info(f"Approving with user: {approver['name']}")
    logger.info(f"Remaining Steps: {response.get('remainingSteps', 'N/A')}")
```

### 4. 재시도 로직
```python
def make_request_with_retry(method, url, **kwargs):
    for attempt in range(ERROR_CONFIG["retry_count"]):
        try:
            # HTTP 요청 실행
            response = requests.request(method, url, **kwargs)
            response.raise_for_status()
            return response
        except requests.exceptions.RequestException as e:
            if attempt < ERROR_CONFIG["retry_count"] - 1:
                time.sleep(ERROR_CONFIG["retry_delay"])
            else:
                raise
```

## 요구사항

### Python 패키지
```bash
pip install requests
```

### 시스템 요구사항
- Python 3.6 이상
- QueryPie API 접근 권한
- 유효한 API 토큰

## 문제 해결

### 일반적인 에러

#### 1. 인증 실패
```
[ERROR] HTTP Error: 401 Client Error: Unauthorized
```
**해결방법**: `config.py`의 `api_token` 값 확인

#### 2. Connection 찾을 수 없음
```
[ERROR] ConnectionError: No suitable connection found
```
**해결방법**: `CONNECTION_CONFIG`의 `preferred_connection_name` 및 `preferred_connection_type` 확인

#### 3. 승인자 없음
```
[ERROR] ApprovalError: No assignees found for step
```
**해결방법**: Approval Rule의 승인자 설정 확인

#### 4. Rule 기반 승인 실패
```
[ERROR] ApprovalError: Approval failed at Step 1
```
**해결방법**: Rule 상세 정보 및 승인자 권한 확인

#### 5. 실행자 없음
```
[ERROR] WorkflowError: No executor available
```
**해결방법**: Approval Rule의 `executionAssignees` 설정 확인

### 디버깅 팁

1. **상세 로그 활성화**:
   ```python
   LOGGING_CONFIG = {
       "verbose": True,
       "show_response": True
   }
   ```

2. **API 응답 확인**: `show_response=True`로 설정하여 API 응답 내용 확인

3. **단계별 실행**: 스크립트의 각 함수를 개별적으로 테스트
   ```python
   # 개별 단계 테스트
   user_uuid = identify_user()
   rules = fetch_approval_rules()
   rule_detail = fetch_approval_rule_detail(rule_uuid)
   ```

4. **Rule 상세 정보 확인**:
   ```python
   # Rule 구조 분석
   step_assignees = get_approval_step_assignees_from_rule(rule_detail)
   execution_assignees = get_execution_assignees_from_rule(rule_detail)
   ```

### 커스텀 예외 처리
스크립트는 세분화된 예외 클래스를 사용하여 문제를 정확히 식별할 수 있습니다:

```python
try:
    main()
except ConnectionError as e:
    logger.error(f"Connection 관련 에러: {e}")
except ApprovalError as e:
    logger.error(f"승인 프로세스 에러: {e}")
except WorkflowError as e:
    logger.error(f"워크플로우 에러: {e}")
```
