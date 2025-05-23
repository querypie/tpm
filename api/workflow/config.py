# 에러 처리 설정
ERROR_CONFIG = {
    "retry_count": 3,       # API 요청 재시도 횟수
    "retry_delay": 1        # 재시도 간격 (초)
}# config.py - QueryPie Workflow Configuration

# API 기본 설정
API_CONFIG = {
    "base_url": "https://elon.querypie-pe.pro/api/external/v2",
    "api_token": "ap01c40f8a-9959-408f-b7a6-e793f3a04314",
    "timeout": 30  # API 요청 타임아웃 (초)
}

# 사용자 설정
USER_CONFIG = {
    "login_id": "qp-admin",  # 요청자 로그인 ID
}

# Workflow 설정
WORKFLOW_CONFIG = {
    "request_type": "SQL_EXECUTION",
    "select_assignee_condition": "ALL_USERS",
    "approval_comments": "Good",
    "urgent": False,
    "use_rule_based_approval": True,  # Rule 기반 승인 사용 여부
    "approval_step_condition": "ANY"  # 기본 승인 조건 (Rule에서 가져오지 못할 경우)
}

# 연결 및 데이터베이스 설정
CONNECTION_CONFIG = {
    "preferred_connection_name": "querypie-metadb",  # 선호하는 연결명
    "preferred_connection_type": "MySQL",             # 선호하는 연결 타입
    "preferred_database": "querypie",                 # 선호하는 데이터베이스명
    "fallback_to_first": True                         # 선호하는 항목이 없을 때 첫 번째 항목 사용 여부
}

# SQL 요청 기본값
SQL_REQUEST_DEFAULTS = {
    "query": "SELECT 1;",
    "title": "SQL Request Submit API Test",
    "comments": "API Test",
    "target_date": "2025-05-22",     # 실행 예정일 (YYYY-MM-DD)
    "expiration_date": "2025-05-30"  # 만료일 (YYYY-MM-DD)
}

# 로깅 설정
LOGGING_CONFIG = {
    "verbose": True,        # 상세 로그 출력 여부
    "show_response": False  # API 응답 내용 출력 여부
}

# Rule 기반 승인 설정
RULE_BASED_APPROVAL_CONFIG = {
    "approval_delay": 1,  # 각 승인 단계 사이의 대기 시간 (초)
    "step_comments": {
        "default": "승인 완료",
        "step_1": "1차 승인 완료",
        "step_2": "2차 승인 완료",
        "step_3": "3차 승인 완료"
    }
}