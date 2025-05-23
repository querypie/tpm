import requests
import time
import logging
from config import (
    API_CONFIG, USER_CONFIG, WORKFLOW_CONFIG,
    CONNECTION_CONFIG, SQL_REQUEST_DEFAULTS,
    LOGGING_CONFIG, ERROR_CONFIG, RULE_BASED_APPROVAL_CONFIG
)

# 상수 정의
BASE_URL = API_CONFIG["base_url"]
HEADERS = {"Authorization": f"Bearer {API_CONFIG['api_token']}"}
TIMEOUT = API_CONFIG["timeout"]
DEFAULT_STEP_CONDITION = "ANY"
FIRST_ASSIGNEE_INDEX = 0
EXECUTION_STATUS = "EXECUTION"

# 로깅 설정
def setup_logging():
    """통일된 로깅 설정"""
    level = logging.DEBUG if LOGGING_CONFIG["verbose"] else logging.INFO
    logging.basicConfig(
        level=level,
        format='[%(levelname)s] %(message)s',
        force=True
    )
    return logging.getLogger(__name__)

logger = setup_logging()

# 커스텀 예외 클래스
class WorkflowError(Exception):
    """워크플로우 관련 예외"""
    pass

class ConnectionError(WorkflowError):
    """연결 관련 예외"""
    pass

class ApprovalError(WorkflowError):
    """승인 관련 예외"""
    pass

def log_response(response_data, title="Response"):
    """응답 데이터 로그 출력"""
    if LOGGING_CONFIG["show_response"]:
        logger.debug(f"[{title}] {response_data}")

def make_request_with_retry(method, url, **kwargs):
    """재시도 로직을 포함한 HTTP 요청"""
    kwargs.setdefault('timeout', TIMEOUT)

    for attempt in range(ERROR_CONFIG["retry_count"]):
        try:
            if method.upper() == 'GET':
                response = requests.get(url, headers=HEADERS, **kwargs)
            elif method.upper() == 'POST':
                response = requests.post(url, headers=HEADERS, **kwargs)
            else:
                raise ValueError(f"Unsupported HTTP method: {method}")

            response.raise_for_status()
            return response
        except requests.exceptions.RequestException as e:
            logger.warning(f"Request failed (attempt {attempt + 1}/{ERROR_CONFIG['retry_count']}): {e}")
            if attempt < ERROR_CONFIG["retry_count"] - 1:
                time.sleep(ERROR_CONFIG["retry_delay"])
            else:
                raise

def identify_user(login_id=None):
    """사용자 UUID 식별"""
    login_id = login_id or USER_CONFIG["login_id"]
    url = f"{BASE_URL}/users/identify"
    response = make_request_with_retry('GET', url, params={"loginId": login_id})
    data = response.json()
    log_response(data, "User Identify")

    if data.get("status") == "FOUND" and data.get("users"):
        return data["users"][0]["uuid"]
    return None

def fetch_approval_rules(request_type=None):
    """Approval Rule 목록 조회"""
    request_type = request_type or WORKFLOW_CONFIG["request_type"]
    url = f"{BASE_URL}/workflows/approval-rules"
    params = {"requestType": request_type}
    response = make_request_with_retry('GET', url, params=params)
    data = response.json()
    log_response(data, "Approval Rules")
    return data

def fetch_database_names(connection_uuid, cluster_uuid, user_uuid):
    """Connection의 Cluster 내 Database 목록 조회"""
    url = f"{BASE_URL}/dac/connections/{connection_uuid}/clusters/{cluster_uuid}/database-names"
    params = {"userUuid": user_uuid}
    response = make_request_with_retry('GET', url, params=params)
    data = response.json()
    log_response(data, "Database Names")
    return data

def fetch_accessible_connections(user_uuid):
    """사용자가 접근할 수 있는 Connection 조회"""
    url = f"{BASE_URL}/workflows/requests/accessible-connections"
    params = {"userUuid": user_uuid}
    response = make_request_with_retry('GET', url, params=params)
    data = response.json()
    log_response(data, "Accessible Connections")
    return data

def fetch_approval_rule_detail(rule_uuid):
    """Approval Rule 상세 정보 조회"""
    url = f"{BASE_URL}/approval-rules/{rule_uuid}"
    response = make_request_with_retry('GET', url)
    data = response.json()
    log_response(data, "Approval Rule Detail")
    return data

def create_approval_steps_from_rule(rule_detail):
    """Approval Rule에서 승인 단계 생성"""
    approval_steps = []
    rule_steps = rule_detail.get("approvalSteps", [])

    logger.info(f"Found {len(rule_steps)} approval step(s) in rule")

    for step_index, step in enumerate(rule_steps):
        rule_assignees = step.get("ruleAssignees", [])
        step_condition = step.get("stepApproveCondition", DEFAULT_STEP_CONDITION)

        if not rule_assignees:
            logger.warning(f"No assignees found for step {step_index + 1}")
            continue

        assignee_uuids = [assignee["uuid"] for assignee in rule_assignees]

        approval_steps.append({
            "assignees": assignee_uuids,
            "stepApproveCondition": step_condition
        })

        # 로깅용으로만 사용
        assignee_names = [assignee["name"] for assignee in rule_assignees]
        logger.info(f"Step {step_index + 1}: {assignee_names} (Condition: {step_condition})")

    return approval_steps

def get_approval_step_assignees_from_rule(rule_detail):
    """Rule에서 각 승인 단계별 승인자 정보 추출"""
    rule_steps = rule_detail.get("approvalSteps", [])
    step_assignees = []

    for step_index, step in enumerate(rule_steps):
        rule_assignees = step.get("ruleAssignees", [])
        if rule_assignees:
            step_assignees.append({
                "step_index": step_index,
                "step_name": f"Step {step_index + 1}",
                "assignees": rule_assignees,
                "condition": step.get("stepApproveCondition", DEFAULT_STEP_CONDITION)
            })

    return step_assignees

def get_execution_assignees_from_rule(rule_detail):
    """Rule에서 실행 담당자 정보 추출"""
    execution_assignees = rule_detail.get("executionAssignees", [])
    if execution_assignees:
        assignee_names = [assignee['name'] for assignee in execution_assignees]
        logger.info(f"Execution assignees from rule: {assignee_names}")
        return execution_assignees
    return []

def approve_single_step(workflow_uuid, step_info, step_index):
    """단일 승인 단계 처리"""
    step_name = step_info["step_name"]

    logger.info(f"Processing {step_name}...")

    # Rule에서 정의된 승인자 중 첫 번째 승인자 사용
    available_approver = step_info["assignees"][FIRST_ASSIGNEE_INDEX]

    logger.info(f"Approving {step_name} with user: {available_approver['name']} (UUID: {available_approver['uuid']})")

    # 승인 댓글 생성
    step_key = f"step_{step_index + 1}"
    comments = RULE_BASED_APPROVAL_CONFIG["step_comments"].get(
        step_key,
        RULE_BASED_APPROVAL_CONFIG["step_comments"]["default"]
    )

    approval_response = approve_sql_request(
        workflow_uuid,
        available_approver["uuid"],
        comments
    )

    logger.info(f"{step_name} completed by {available_approver['name']}")
    logger.info(f"Remaining Steps: {approval_response.get('remainingSteps', 'N/A')}")

    return {
        "step": step_name,
        "approver": available_approver["name"],
        "approver_uuid": available_approver["uuid"],
        "response": approval_response
    }

def approve_sql_request_with_rule(workflow_uuid, rule_detail):
    """Rule 기반 다단계 SQL Request 결재"""
    step_assignees = get_approval_step_assignees_from_rule(rule_detail)

    if not step_assignees:
        raise ApprovalError("No approval steps found in rule")

    step_results = []

    for step_info in step_assignees:
        step_index = step_info["step_index"]

        try:
            result = approve_single_step(workflow_uuid, step_info, step_index)
            step_results.append(result)

            # 최종 승인이 완료되었는지 확인
            if result["response"].get('remainingSteps') == EXECUTION_STATUS:
                logger.info("All approval steps completed!")
                break

            # 다음 단계로 넘어가기 전 잠시 대기
            if step_index < len(step_assignees) - 1:
                time.sleep(RULE_BASED_APPROVAL_CONFIG["approval_delay"])

        except Exception as e:
            logger.error(f"Error in {step_info['step_name']}: {e}")
            raise ApprovalError(f"Approval failed at {step_info['step_name']}: {e}")

    return step_results

def create_sql_request(requester_uuid, rule_uuid, cluster_uuid, database_name,
                       approval_steps, query=None, title=None, comments=None,
                       target_date=None, expiration_date=None, urgent=None):
    """SQL Request 상신 (Rule 기반 승인 지원)"""
    url = f"{BASE_URL}/workflows/sql-request"
    payload = {
        "requesterUuid": requester_uuid,
        "ruleUuid": rule_uuid,
        "clusterUuid": cluster_uuid,
        "databaseName": database_name,
        "content": query or SQL_REQUEST_DEFAULTS["query"],
        "title": title or SQL_REQUEST_DEFAULTS["title"],
        "comments": comments or SQL_REQUEST_DEFAULTS["comments"],
        "targetDate": target_date or SQL_REQUEST_DEFAULTS["target_date"],
        "expirationDate": expiration_date or SQL_REQUEST_DEFAULTS["expiration_date"],
        "urgent": urgent if urgent is not None else WORKFLOW_CONFIG["urgent"],
        "approvalSteps": approval_steps
    }
    response = make_request_with_retry('POST', url, json=payload)
    data = response.json()
    log_response(data, "SQL Request Creation")
    return data

def approve_sql_request(workflow_uuid, approver_uuid, comments=None):
    """SQL Request 결재"""
    url = f"{BASE_URL}/workflows/{workflow_uuid}/approve"
    payload = {
        "userUuid": approver_uuid,
        "comments": comments or WORKFLOW_CONFIG["approval_comments"]
    }
    response = make_request_with_retry('POST', url, json=payload)
    data = response.json()
    log_response(data, "Approval")
    return data

def execute_sql_request(workflow_uuid, user_uuid):
    """SQL Request 실행"""
    url = f"{BASE_URL}/workflows/sql-request/{workflow_uuid}/execute"
    payload = {"userUuid": user_uuid}
    response = make_request_with_retry('POST', url, json=payload)

    # 실행 API는 빈 응답을 반환할 수 있음
    try:
        data = response.json()
        log_response(data, "Execution")
        return data
    except ValueError:
        logger.info("Execution completed with empty response (200 OK)")
        return None

def select_connection(connections):
    """선호하는 연결 선택"""
    preferred_name = CONNECTION_CONFIG["preferred_connection_name"]
    preferred_type = CONNECTION_CONFIG["preferred_connection_type"]

    # 선호하는 이름과 타입으로 검색
    for conn in connections:
        if (conn["name"] == preferred_name and
                conn["type"] == preferred_type):
            return conn

    # 선호하는 타입으로만 검색
    for conn in connections:
        if conn["type"] == preferred_type:
            return conn

    # 대체 옵션 사용
    if CONNECTION_CONFIG["fallback_to_first"] and connections:
        return connections[0]

    return None

def select_database(database_names):
    """선호하는 데이터베이스 선택"""
    preferred_db = CONNECTION_CONFIG["preferred_database"]

    if preferred_db in database_names:
        return preferred_db

    if CONNECTION_CONFIG["fallback_to_first"] and database_names:
        return database_names[0]

    return None

def setup_workflow():
    """워크플로우 초기 설정"""
    logger.info("Starting QueryPie Workflow...")

    # 사용자 UUID 식별
    user_uuid = identify_user()
    if not user_uuid:
        raise WorkflowError("Failed to identify user")
    logger.info(f"User UUID: {user_uuid}")

    # SQL_EXECUTION에 해당하는 Approval Rule 조회
    rules = fetch_approval_rules()
    if not rules.get("list"):
        raise WorkflowError("No SQL_EXECUTION approval rules found")

    approval_rule_uuid = rules["list"][0]["uuid"]
    logger.info(f"Selected Approval Rule UUID: {approval_rule_uuid}")
    logger.info(f"Approval Rule Name: {rules['list'][0]['name']}")

    # Approval Rule 상세 정보 조회
    logger.info("Fetching approval rule details...")
    rule_detail = fetch_approval_rule_detail(approval_rule_uuid)
    logger.info(f"Rule has {len(rule_detail.get('approvalSteps', []))} approval step(s)")

    return user_uuid, approval_rule_uuid, rule_detail

def setup_connection(user_uuid):
    """연결 및 데이터베이스 설정"""
    # 사용자가 접근 가능한 Connection 조회
    connections = fetch_accessible_connections(user_uuid)

    # 선호하는 Connection 선택
    selected_connection = select_connection(connections)
    if not selected_connection:
        raise ConnectionError(f"No suitable connection found (preferred: {CONNECTION_CONFIG['preferred_connection_name']})")

    connection_uuid = selected_connection["uuid"]
    cluster_uuid = selected_connection["clusters"][0]["uuid"]
    logger.info(f"Selected Connection: {selected_connection['name']} ({selected_connection['type']})")
    logger.info(f"Connection UUID: {connection_uuid}")
    logger.info(f"Cluster UUID: {cluster_uuid}")

    # Connection의 Database 목록 조회
    databases_response = fetch_database_names(connection_uuid, cluster_uuid, user_uuid)
    database_names = databases_response.get("databaseNames", [])

    # 선호하는 데이터베이스 선택
    selected_database = select_database(database_names)
    if not selected_database:
        raise ConnectionError(f"No suitable database found (preferred: {CONNECTION_CONFIG['preferred_database']})")

    logger.info(f"Available Databases: {database_names}")
    logger.info(f"Selected Database: {selected_database}")

    return connection_uuid, cluster_uuid, selected_database

def create_and_submit_request(user_uuid, approval_rule_uuid, rule_detail, cluster_uuid, selected_database):
    """SQL Request 생성 및 상신"""
    # Rule에서 승인 단계 생성
    approval_steps = create_approval_steps_from_rule(rule_detail)

    if not approval_steps:
        raise WorkflowError("No approval steps could be created from rule")

    logger.info(f"Created {len(approval_steps)} approval step(s) from rule")

    # SQL Request 상신
    logger.info("Creating SQL Request...")
    sql_request = create_sql_request(
        requester_uuid=user_uuid,
        rule_uuid=approval_rule_uuid,
        cluster_uuid=cluster_uuid,
        database_name=selected_database,
        approval_steps=approval_steps
    )
    workflow_uuid = sql_request["workflowUuid"]
    logger.info(f"SQL Request created successfully!")
    logger.info(f"Workflow UUID: {workflow_uuid}")

    return workflow_uuid

def process_approval_workflow(workflow_uuid, rule_detail):
    """승인 워크플로우 처리"""
    logger.info("Starting rule-based approval process...")

    if not (WORKFLOW_CONFIG["use_rule_based_approval"] and rule_detail.get("approvalSteps")):
        logger.info("Rule-based approval disabled or no approval steps found")
        return []

    approval_results = approve_sql_request_with_rule(workflow_uuid, rule_detail)
    logger.info("Rule-based approval process completed!")

    for result in approval_results:
        logger.info(f"- {result['step']}: Approved by {result['approver']}")

    return approval_results

def execute_workflow(workflow_uuid, rule_detail):
    """워크플로우 실행"""
    logger.info("Executing SQL Request...")

    execution_assignees = get_execution_assignees_from_rule(rule_detail)
    if not execution_assignees:
        raise WorkflowError("No executor available")

    executor_uuid = execution_assignees[0]["uuid"]
    executor_name = execution_assignees[0]["name"]
    logger.info(f"Using rule-defined executor: {executor_name}")

    execution_response = execute_sql_request(workflow_uuid, executor_uuid)
    logger.info(f"Execution completed successfully by {executor_name}!")

    if execution_response:
        logger.info(f"Execution Response: {execution_response}")

    return execution_response

def main():
    """메인 워크플로우 실행"""
    try:
        # 1. 워크플로우 초기 설정
        user_uuid, approval_rule_uuid, rule_detail = setup_workflow()

        # 2. 연결 및 데이터베이스 설정
        connection_uuid, cluster_uuid, selected_database = setup_connection(user_uuid)

        # 3. SQL Request 생성 및 상신
        workflow_uuid = create_and_submit_request(
            user_uuid, approval_rule_uuid, rule_detail, cluster_uuid, selected_database
        )

        # 4. 승인 워크플로우 처리
        process_approval_workflow(workflow_uuid, rule_detail)

        # 5. SQL Request 실행
        execute_workflow(workflow_uuid, rule_detail)

        logger.info("Workflow completed successfully!")

    except WorkflowError as e:
        logger.error(f"Workflow Error: {e}")
        raise
    except requests.exceptions.RequestException as e:
        logger.error(f"HTTP Error: {e}")
        if hasattr(e, 'response') and e.response is not None:
            logger.error(f"Response status: {e.response.status_code}")
            logger.error(f"Response body: {e.response.text}")
        raise
    except Exception as e:
        logger.error(f"Unexpected Error: {e}")
        raise

# 스크립트 직접 실행 시에만 main 함수 호출
if __name__ == "__main__":
    main()