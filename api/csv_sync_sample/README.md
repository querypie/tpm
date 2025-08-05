# CSV 처리 프로그램

이 프로젝트는 CSV 파일을 읽고 처리하는 파이썬 프로그램입니다.

## 기능

### 1. 사용자 등록 프로그램

- CSV 파일에서 사용자 정보 읽기
- 사용자 존재 여부 확인
- API를 통한 새 사용자 등록

### 2. 서버 및 서버 그룹 관리 프로그램

- CSV 파일에서 서버 정보 읽기
- 서버 등록 및 태그 추가
- 서버 그룹 생성
- 서버 그룹에 계정 추가

### 3. 정책 및 역할 관리 프로그램

- 서버 그룹별 계정 추출
- 서버 그룹별 정책 생성 및 내용 업데이트
- 서버 그룹별 역할 생성 및 정책 연결

### 4. 역할 할당 프로그램

- CSV 파일에서 사용자 정보 및 역할 읽기
- API를 통한 사용자 검색
- 사용자에게 지정된 역할 부여
- 역할이 이미 할당된 사용자 건너뛰기

### 5. 통합 처리 프로그램

- 사용자 및 서버 CSV 파일 두 개를 입력으로 받음
- 위 4가지 프로그램을 순차적으로 실행
- 중간 실패 시 전체 프로세스 중단
- 과정별 진행 상황 로깅

## 설치 방법

```bash
# 프로젝트 클론
git clone [repository_url]
cd csv-processor

# 필요한 패키지 설치
pip install -r requirements.txt
```

## 사용 방법

### 사용자 등록 프로그램

```bash
# API URL과 API Key를 명령행 인자로 제공
python process_users.py data/sample_users.csv --api-url https://example.com --api-key your-api-key

# 또는 환경 변수로 제공
export API_BASE_URL=https://example.com
export API_KEY=your-api-key
python process_users.py data/sample_users.csv
```

### 서버 및 서버 그룹 관리 프로그램

```bash
# API URL과 API Key를 명령행 인자로 제공
python process_servers.py data/sample_servers.csv --api-url https://example.com --api-key your-api-key

# 또는 환경 변수로 제공
export API_BASE_URL=https://example.com
export API_KEY=your-api-key
python process_servers.py data/sample_servers.csv
```

### 정책 및 역할 관리 프로그램

```bash
# API URL과 API Key를 명령행 인자로 제공
python process_policies.py data/sample_servers.csv --api-url https://example.com --api-key your-api-key

# 또는 환경 변수로 제공
export API_BASE_URL=https://example.com
export API_KEY=your-api-key
python process_policies.py data/sample_servers.csv
```

### 역할 할당 프로그램

```bash
# API URL과 API Key를 명령행 인자로 제공
python process_roles.py data/sample_users.csv --api-url https://example.com --api-key your-api-key

# 또는 환경 변수로 제공
export API_BASE_URL=https://example.com
export API_KEY=your-api-key
python process_roles.py data/sample_users.csv
```

### 통합 처리 프로그램

```bash
# API URL과 API Key를 명령행 인자로 제공
python process_all.py data/sample_users.csv data/sample_servers.csv --api-url https://example.com --api-key your-api-key

# 또는 환경 변수로 제공
export API_BASE_URL=https://example.com
export API_KEY=your-api-key
python process_all.py data/sample_users.csv data/sample_servers.csv
```

## 프로젝트 구조

- `process_users.py`: 사용자 등록 프로그램 진입점
- `user_processor.py`: 사용자 CSV 처리 로직
- `process_servers.py`: 서버 관리 프로그램 진입점
- `server_processor.py`: 서버 CSV 처리 로직
- `process_policies.py`: 정책 및 역할 관리 프로그램 진입점
- `policy_processor.py`: 정책 및 역할 처리 로직
- `process_roles.py`: 역할 할당 프로그램 진입점
- `role_assigner.py`: 역할 할당 처리 로직
- `process_all.py`: 모든 처리를 순차 실행하는 통합 프로그램
- `tests/`: 테스트 코드
- `data/`: 샘플 CSV 파일

## CSV 파일 형식

### 사용자 CSV 형식
```
email,loginId,name,password,role
user1@example.com,user1,사용자1,password123,ADMIN
```
(role 필드는 선택 사항이며, 세미콜론(;)으로 구분하여 여러 역할을 지정할 수 있습니다)

### 서버 CSV 형식
```
host,name,osType,sshport,server_group,account_name
10.10.10.10,server1,AWS_LINUX,22,WEB_GROUP,ec2-user
```

### 역할 할당 CSV 형식
```
email,loginId,name,password,role
user1@example.com,user1,User 1,password123,ADMIN
user2@example.com,user2,User 2,password456,USER;MANAGER
```
(여기서 'role' 값에 'role'을 붙여 역할명이 생성되며, 세미콜론(;)으로 구분하여 여러 역할을 지정할 수 있습니다. 예: 'ADMIN role', 'USER role', 'MANAGER role')

## 정책 형식

정책은 다음과 같은 YAML 형식으로 생성됩니다:

```yaml
apiVersion: server.rbac.querypie.com/v1
kind: SacPolicy

spec:
  allow:
    resources:
      - serverGroup: {{server_group}}
        account: {{account_name}}
    actions:
      protocols: ["ssh", "sftp"]
      commandsRef: "Default Policy"
    conditions:
      accessTime: "00:00-23:59"
      accessWeekday: ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
      ipAddresses: ["0.0.0.0/0"] 
    options: 
      commandAudit: true
      commandDetection: false
      useProxy: true
      maxSessions: 5
      sessionTimeout: 10
```

## 요구 사항

Python 3.6 이상
