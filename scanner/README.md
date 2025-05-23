# QueryPie Scanner

MySQL과 Redis 연결을 테스트하는 도구입니다. 로컬 환경과 Docker 컨테이너에서 MySQL과 Redis 서버의 연결 상태를 확인할 수 있습니다.

## 기능

- MySQL 연결 테스트
  - 로컬 환경에서의 연결 테스트
  - Docker 컨테이너에서의 연결 테스트
  - MySQL 클라이언트 또는 netcat을 사용한 연결 확인
  - 서버 버전 정보 확인 (verbose 모드)

- Redis 연결 테스트
  - 로컬 환경에서의 연결 테스트
  - Docker 컨테이너에서의 연결 테스트
  - redis-cli 또는 netcat을 사용한 연결 확인
  - 서버 버전 정보 확인 (verbose 모드)

- Docker 컨테이너 리소스 모니터링 (verbose 모드)
  - CPU 사용량
  - 메모리 사용량
  - 네트워크 I/O
  - 디스크 사용량

## 파일명
`scanner.sh`

## 사전 준비
1. 신규버전 디렉토리로 이동
   ```bash
   cd ./querypie/버전  # compose-env 파일이 존재하는 디렉토리로 이동
   ```
2. scanner.sh 다운로드
   ```bash
   curl -l https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/scanner/scanner.sh -o scanner.sh
   ```
3. 실행 권한 추가
   ```bash
   chmod +x scanner.sh
   ```

## 사용법

```bash
./scanner.sh              # 기본 실행
./scanner.sh -v          # 상세 모드로 실행
./scanner.sh <container> # 특정 컨테이너 지정하여 실행
./scanner.sh -h          # 도움말 표시

주의사항) querypie-tools 나 querypie-app 이 도커 인스턴스로 떠 있어야 함.
```

## 테스트 순서

### 1. 로컬 환경 테스트
- MySQL 연결 테스트
  1. mysql client
  2. netcat
  3. SSH

- Redis 연결 테스트
  1. redis-cli
  2. netcat
  3. SSH

### 2. Docker 컨테이너 테스트
- MySQL 연결 테스트
  1. mysql client
  2. netcat
  3. SSH

- Redis 연결 테스트
  1. redis-cli
  2. netcat
  3. SSH

## 성공/실패 조건

### MySQL 연결 테스트
- 성공 조건:
  - mysql client: 연결 성공 및 버전 확인
  - netcat: MySQL 서버 응답 확인
  - SSH: MySQL 서버 응답 확인

- 실패 조건:
  - 포트가 닫혀있거나 접근 불가
  - 인증 실패
  - 연결 타임아웃

### Redis 연결 테스트
- 성공 조건:
  - redis-cli: PONG 응답 수신
  - netcat: PONG 응답 수신
  - SSH: PONG 응답 수신

- 실패 조건:
  - 포트가 닫혀있거나 접근 불가
  - 인증 실패 (비밀번호가 필요한 경우)
  - 연결 타임아웃

## 주의사항
- Redis의 경우 AUTH 경고가 표시되더라도 PONG 응답을 받으면 연결 성공으로 간주
- Docker 컨테이너 테스트는 로컬 테스트가 실패한 경우에도 실행
- SSH 테스트는 이전 방법들이 모두 실패한 경우에만 실행

## 환경 설정

스크립트는 `compose-env` 파일에서 다음 환경 변수들을 읽어옵니다:

- MySQL 설정
  - `DB_HOST`: MySQL 서버 호스트
  - `DB_PORT`: MySQL 서버 포트
  - `DB_USERNAME`: MySQL 사용자 이름
  - `DB_PASSWORD`: MySQL 비밀번호
  - `DB_CATALOG`: MySQL 데이터베이스 이름

- Redis 설정
  - `REDIS_HOST`: Redis 서버 호스트
  - `REDIS_PORT`: Redis 서버 포트
  - `REDIS_CONNECTION_MODE`: STANDALONE or CLUSTER
  - `REDIS_NODES`: Redis node
  - `REDIS_PASSWORD`: Redis 비밀번호 (선택사항)

## 출력 형식

- 성공 메시지: 초록색
- 경고 메시지: 노란색
- 에러 메시지: 빨간색
- 정보 메시지: 밝은 청록색

## 종료 코드

- 0: 모든 연결 테스트 성공
- 1: 하나 이상의 연결 테스트 실패

## 요구사항

- bash
- Docker (Docker 컨테이너 테스트용)
- MySQL 클라이언트 또는 netcat (MySQL 테스트용)
- redis-cli 또는 netcat (Redis 테스트용)


---

# QueryPie Scanner (English)

A tool for testing MySQL and Redis connections. It can verify the connection status of MySQL and Redis servers in both local environments and Docker containers.

## Features

- MySQL Connection Testing
  - Local environment connection testing
  - Docker container connection testing
  - Connection verification using MySQL client or netcat
  - Server version information check (verbose mode)

- Redis Connection Testing
  - Local environment connection testing
  - Docker container connection testing
  - Connection verification using redis-cli or netcat
  - Server version information check (verbose mode)

- Docker Container Resource Monitoring (verbose mode)
  - CPU usage
  - Memory usage
  - Network I/O
  - Disk usage

## File Name
`scanner.sh`

## Prerequisites
1. Move to new version directory
   ```bash
   cd ./querypie/version  # Move to directory containing compose-env file
   ```
2. Download scanner.sh
   ```bash
   curl -l https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/scanner/scanner.sh -o scanner.sh
   ```
3. Add execution permission
   ```bash
   chmod +x scanner.sh
   ```

## Usage

```bash
./scanner.sh              # Basic execution
./scanner.sh -v          # Execute in verbose mode
./scanner.sh <container> # Execute for specific container
./scanner.sh -h          # Display help

Note: querypie-tools or querypie-app must be running as Docker instances.
```

## Test Sequence

### 1. Local Environment Testing
- MySQL Connection Testing
  1. mysql client
  2. netcat
  3. SSH

- Redis Connection Testing
  1. redis-cli
  2. netcat
  3. SSH

### 2. Docker Container Testing
- MySQL Connection Testing
  1. mysql client
  2. netcat
  3. SSH

- Redis Connection Testing
  1. redis-cli
  2. netcat
  3. SSH

## Success/Failure Conditions

### MySQL Connection Testing
- Success Conditions:
  - mysql client: Successful connection and version verification
  - netcat: MySQL server response verification
  - SSH: MySQL server response verification

- Failure Conditions:
  - Port closed or inaccessible
  - Authentication failure
  - Connection timeout

### Redis Connection Testing
- Success Conditions:
  - redis-cli: Receiving PONG response
  - netcat: Receiving PONG response
  - SSH: Receiving PONG response

- Failure Conditions:
  - Port closed or inaccessible
  - Authentication failure (when password is required)
  - Connection timeout

## Precautions
- For Redis, connection is considered successful if PONG response is received, even if AUTH warning is displayed
- Docker container testing is executed even if local testing fails
- SSH testing is only executed if all previous methods fail

## Environment Configuration

The script reads the following environment variables from the `compose-env` file:

- MySQL Settings
  - `DB_HOST`: MySQL server host
  - `DB_PORT`: MySQL server port
  - `DB_USERNAME`: MySQL username
  - `DB_PASSWORD`: MySQL password
  - `DB_CATALOG`: MySQL database name

- Redis Settings
  - `REDIS_HOST`: Redis server host
  - `REDIS_PORT`: Redis server port
  - `REDIS_CONNECTION_MODE`: STANDALONE or CLUSTER
  - `REDIS_NODES`: Redis node
  - `REDIS_PASSWORD`: Redis password (optional)

## Output Format

- Success messages: Green
- Warning messages: Yellow
- Error messages: Red
- Information messages: Light cyan

## Exit Codes

- 0: All connection tests successful
- 1: One or more connection tests failed

## Requirements

- bash
- Docker (for Docker container testing)
- MySQL client or netcat (for MySQL testing)
- redis-cli or netcat (for Redis testing)


