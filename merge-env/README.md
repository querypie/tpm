# Introduction

QueryPie 업그레이드 시 compose-env의 빈 값을 채워주고 필요한 파일들(certs, novac-compose.yml, skip_command_config.json)을 복사하는 스크립트 (from: 이전버전, to: 신규버전)

QueryPie Redis Cluster 설정 지원


# 파일명
- merge-env.sh


# 사전 준비
### 신규버전 디렉토리로 이동  

    cd ./querypie/신규버전 혹은 신규버전 compose-env 파일이 존재하는 디렉토리로 이동

### merge-env.sh 다운로드  

    curl -l https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/merge-env/merge-env.sh -o merge-env.sh

### 실행 권한 추가  
    chmod +x merge-env.sh


# 사용법
```
./merge-env.sh 이전버전 --dry-run
```  
  - 파일 변경 없이 비교 결과 콘솔 출력
```
./merge-env.sh 이전버전
```
  - 신규버전 compose-env 파일내 빈 값을 이전버전 내용으로 채워서 저장 (기존 파일 backup 으로 저장)
  - 필요한 파일들(certs, novac-compose.yml, skip_command_config.json) 복사
  - 콘솔 출력
  - 원본 compose-env copy to compose-env.backup (최초 한번만 copy)
  - 신규 compose-env copy to compose-env.backup.timestamp (매 실행시 copy)
  - compose-env 값 변경 (신규 compose-env 키 값 기준)
    - 키 o & 값 o : 신규 값 유지
    - 키 o & 값 x : 이전버전에서 값 copy
    - 키 x : 키 삭제로 코멘트 표시 (이전버전에만 존재)
```
./merge-env.sh 이전버전 -y
```
  - 모든 파일 복사 시 사용자 확인 없이 자동으로 진행
  - certs, novac-compose.yml, skip_command_config.json 파일 복사 시 확인 메시지 없이 자동 복사
```
./merge-env.sh 이전버전 --force-update
```
  - 신규버전의 값이 있더라도 이전버전의 값으로 강제 업데이트
  - 이전버전의 값이 신규버전의 값을 덮어씀
  - --dry-run 옵션과 함께 사용할 수 없음
  - 콘솔 출력에 force update 모드로 변경된 내용 표시
```
./merge-env.sh undo
```   
  - 초기 compose-env 로 원복

## 예시)  10.1.9 -> 10.2.4  (10.2.4 디렉토리에서 실행)
    ./merge-env.sh 10.1.9 --dry-run  

    ./merge-env.sh 10.1.9  

    ./merge-env.sh 10.1.9 -y  # 사용자 확인 없이 자동으로 모든 파일 복사

    ./merge-env.sh undo

## 콘솔 출력 내용
```  
./merge-env.sh 10.2.4 
Timestamp backup file created: ./compose-env.backup_20250328095209
✅  Starting merge process. Files will be modified.

Result file: ./compose-env

===== Key Comparison Results =====
Original file: ../10.2.4/compose-env
New file: ./compose-env

[Unchanged Keys]
Key 'VERSION' value unchanged: '10.2.4'
Key 'AWS_ACCOUNT_ID' value unchanged (both empty)
Key 'DB_PORT' value unchanged: '3306'
Key 'DB_CATALOG' value unchanged: 'querypie'
Key 'LOG_DB_CATALOG' value unchanged: 'querypie_log'
Key 'ENG_DB_CATALOG' value unchanged: 'querypie_snapshot'
Key 'DB_MAX_CONNECTION_SIZE' value unchanged: '20'
Key 'DB_DRIVER_CLASS' value unchanged: 'org.mariadb.jdbc.Driver'
Key 'REDIS_PORT' value unchanged: '6379'
Key 'DAC_SKIP_SQL_COMMAND_RULE_FILE' value unchanged: 'skip_command_config.json'
Key 'CABINET_DATA_DIR' value unchanged: '/data'

[Keys Filled with Original Values]
Key 'AGENT_SECRET' empty value replaced with original: '12345678901234567890123456789012'
Key 'KEY_ENCRYPTION_KEY' empty value replaced with original: 'querypie'
Key 'QUERYPIE_WEB_URL' empty value replaced with original: 'http://172.31.54.186'
Key 'DB_HOST' empty value replaced with original: '172.31.54.186'
Key 'DB_USERNAME' empty value replaced with original: 'querypie'
Key 'DB_PASSWORD' empty value replaced with original: 'xxxxxx'
Key 'REDIS_HOST' empty value replaced with original: '172.31.54.186'
Key 'REDIS_PASSWORD' empty value replaced with original: 'xxxxxx'

✅  Key comparison complete. Proceeding with file operations.

===== File Operations =====

⚙️  About to handle certs directory

Copy certs from ../10.2.4/certs to ./certs
Do you want to proceed? (y/Enter for yes, any other key for no): 
Copying new certs:
  - Source: ../10.2.4/certs
  - Destination: ./certs
  ✓ Successfully copied certs directory


⚙️  About to handle novac-compose.yml

Copy ../10.2.4/novac-compose.yml to ./novac-compose.yml
Do you want to proceed? (y/Enter for yes, any other key for no): 
Created backup: ./novac-compose.yml.backup_20250328095210
Successfully copied ../10.2.4/novac-compose.yml to ./novac-compose.yml


⚙️  About to handle skip_command_config.json

Copy ../10.2.4/skip_command_config.json to ./skip_command_config.json
Do you want to proceed? (y/Enter for yes, any other key for no): 
Created backup: ./skip_command_config.json.backup_20250328095210
Successfully copied ../10.2.4/skip_command_config.json to ./skip_command_config.json

✅  All operations completed successfully
```  

# 상세 사용 설명서

## 1. 스크립트 실행 전 준비사항

### 1.1 디렉토리 구조
```
querypie/
├── 10.1.9/              # 이전 버전 디렉토리
│   ├── compose-env      # 이전 버전 환경 설정 파일
│   ├── certs/           # 인증서 디렉토리
│   ├── novac-compose.yml # Nova 설정 파일
│   └── skip_command_config.json # SQL 명령어 스킵 설정
└── 10.2.4/              # 신규 버전 디렉토리
    ├── merge-env.sh     # 스크립트 파일
    ├── compose-env      # 신규 버전 환경 설정 파일
    ├── certs/           # 인증서 디렉토리 (복사됨)
    ├── novac-compose.yml # Nova 설정 파일 (복사됨)
    └── skip_command_config.json # SQL 명령어 스킵 설정 (복사됨)
```

### 1.2 필수 조건
- 신규 버전 디렉토리에 `compose-env` 파일이 존재해야 함
- 이전 버전 디렉토리에 `compose-env` 파일이 존재해야 함
- 스크립트 실행 권한이 있어야 함
- 이전 버전 디렉토리에 다음 파일들이 존재해야 함:
  - `certs/` 디렉토리
  - `novac-compose.yml`
  - `skip_command_config.json`

## 2. 실행 모드 설명

### 2.1 드라이 런 모드 (--dry-run)
```bash
./merge-env.sh 이전버전 --dry-run
```
- 실제 파일 변경 없이 비교 결과만 확인
- 백업 파일 생성하지 않음
- 안전하게 변경 사항 미리 확인 가능
- 다음 정보를 출력:
  - 변경되지 않은 키
  - 이전 버전의 값으로 채워질 키
  - 값이 변경된 키
  - 신규 추가된 키
  - 제거된 키

### 2.2 강제 업데이트 모드 (--force-update)
```bash
./merge-env.sh 이전버전 --force-update
```
- 신규버전의 값이 있더라도 이전버전의 값으로 강제 업데이트
- --dry-run 옵션과 함께 사용할 수 없음
- 다음 작업 수행:
  1. 신규버전에 값이 있는 키도 이전버전의 값으로 덮어씀
  2. 신규버전에만 있는 키는 그대로 유지
  3. 이전버전에만 있는 키는 주석으로 표시
- 콘솔 출력에서 force update로 변경된 내용 확인 가능:
  - [Changed Keys] 섹션에 "(force update mode)" 표시
  - 이전 값과 현재 값을 명확히 구분하여 표시

### 2.3 실제 실행 모드
```bash
./merge-env.sh 이전버전
```
- 실제 파일 변경 수행
- 자동 백업 생성
- 변경 사항 적용 및 결과 출력
- 다음 작업 수행:
  1. 최초 실행 시: `compose-env` → `compose-env.backup` 복사
  2. 매 실행 시: `compose-env` → `compose-env.backup.timestamp` 복사
  3. 환경 설정 값 병합:
     - 키와 값이 모두 있는 경우: 신규 값 유지
     - 키는 있지만 값이 없는 경우: 이전 버전의 값으로 채움
     - 이전 버전에만 있는 키: 주석으로 표시
  4. 추가 파일 복사:
     - `certs/` 디렉토리 복사
     - `novac-compose.yml` 복사 (백업 생성)
     - `skip_command_config.json` 복사 (백업 생성)

### 2.4 자동 확인 모드 (-y)
```bash
./merge-env.sh 이전버전 -y
```
  - 모든 파일 복사 시 사용자 확인 없이 자동으로 진행
  - certs, novac-compose.yml, skip_command_config.json 파일 복사 시 확인 메시지 없이 자동 복사
```
./merge-env.sh undo
```
- 마지막 백업 파일에서 복원
- `compose-env.backup` 파일이 있어야 함
- 모든 변경 사항을 원래 상태로 복원

## 3. 출력 결과 해석

### 3.1 키 비교 결과 카테고리
1. **Unchanged Keys**
   - 변경되지 않은 키 목록
   - 값이 동일하거나 둘 다 비어있는 경우

2. **Keys Filled with Original Values**
   - 이전 버전의 값으로 채워진 키 목록
   - 신규 버전에서 값이 비어있던 키들

3. **Changed Keys**
   - 값이 변경된 키 목록
   - 이전 버전과 신규 버전의 값이 다른 경우

4. **New Keys**
   - 신규 버전에만 존재하는 키 목록
   - 이전 버전에는 없던 새로운 설정

5. **Removed Keys**
   - 이전 버전에만 존재하는 키 목록
   - 신규 버전에서 제거된 설정

### 3.2 파일 작업 결과
1. **certs 디렉토리**
   - 소스 및 대상 경로 표시
   - 복사 성공 여부 확인

2. **novac-compose.yml**
   - 백업 파일 생성 정보
   - 복사 성공 여부 확인

3. **skip_command_config.json**
   - 백업 파일 생성 정보
   - 복사 성공 여부 확인

### 3.3 출력 형식
- 컬러 코딩된 출력으로 가독성 향상
- 각 카테고리별로 구분된 섹션
- 변경 사항의 이전/이후 값을 명확히 표시
- 이모지를 사용한 작업 상태 표시
- 사용자 확인 요청 메시지

## 4. 주의사항

### 4.1 실행 전
- 반드시 드라이 런 모드로 먼저 실행하여 변경 사항 확인
- 충분한 디스크 공간 확보 (백업 파일 생성)
- 실행 권한 확인
- 필요한 파일들의 존재 여부 확인

### 4.2 실행 중
- 백업 파일 생성 실패 시 즉시 중단
- 파일 접근 권한 문제 발생 시 확인 필요
- 충분한 시스템 리소스 확보
- 각 파일 복사 시 사용자 확인 필요

### 4.3 실행 후
- 백업 파일 보관
- 변경 사항 검증
- 문제 발생 시 undo 모드로 복원 가능
- 복사된 파일들의 정상 동작 확인

## 5. 문제 해결

### 5.1 일반적인 문제
1. **실행 권한 오류**
   ```bash
   chmod +x merge-env.sh
   ```

2. **파일 없음 오류**
   - 이전 버전 디렉토리 확인
   - compose-env 파일 존재 확인
   - certs 디렉토리 존재 확인
   - novac-compose.yml 파일 존재 확인
   - skip_command_config.json 파일 존재 확인

3. **백업 실패**
   - 디스크 공간 확인
   - 파일 권한 확인

### 5.2 복구 방법
1. **실행 취소**
   ```bash
   ./merge-env.sh undo
   ```

2. **수동 복구**
   - 백업 파일에서 수동 복원
   - 타임스탬프가 포함된 백업 파일 사용
   - certs 디렉토리 수동 복원
   - novac-compose.yml 수동 복원
   - skip_command_config.json 수동 복원



---

# Introduction (English)

A script that fills empty values in compose-env and copies necessary files (certs, novac-compose.yml, skip_command_config.json) during QueryPie upgrades (from: previous version, to: new version)

Supports QueryPie Redis Cluster configuration

# File Name
- merge-env.sh

# Prerequisites
### Move to New Version Directory

    cd ./querypie/new_version or move to the directory where the new version's compose-env file exists

### Download merge-env.sh

    curl -l https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/merge-env/merge-env.sh -o merge-env.sh

### Add Execution Permission
    chmod +x merge-env.sh

# Usage
```
./merge-env.sh previous_version --dry-run
```  
  - Console output of comparison results without file changes
```
./merge-env.sh previous_version
```
  - Fill empty values in the new version's compose-env file with previous version's content (save existing file as backup)
  - Copy necessary files (certs, novac-compose.yml, skip_command_config.json)
  - Console output
  - Original compose-env copy to compose-env.backup (copy only once)
  - New compose-env copy to compose-env.backup.timestamp (copy on each execution)
  - Modify compose-env values (based on new compose-env key values)
    - Key exists & value exists: Keep new value
    - Key exists & value empty: Copy value from previous version
    - Key doesn't exist: Mark as comment (exists only in previous version)
```
./merge-env.sh previous_version -y
```
  - Automatically proceed without user confirmation for all file copies
  - Automatically copy certs, novac-compose.yml, skip_command_config.json files without confirmation messages
```
./merge-env.sh previous_version --force-update
```
  - Force update with previous version's values even if new version has values
  - Previous version's values overwrite new version's values
  - Cannot be used with --dry-run option
  - Console output shows changes made in force update mode
```
./merge-env.sh undo
```   
  - Restore to initial compose-env

## Example) 10.1.9 -> 10.2.4 (Execute in 10.2.4 directory)
    ./merge-env.sh 10.1.9 --dry-run  

    ./merge-env.sh 10.1.9  

    ./merge-env.sh 10.1.9 -y  # Automatically copy all files without user confirmation

    ./merge-env.sh undo

## Console Output
```  
./merge-env.sh 10.2.4 
Timestamp backup file created: ./compose-env.backup_20250328095209
✅  Starting merge process. Files will be modified.

Result file: ./compose-env

===== Key Comparison Results =====
Original file: ../10.2.4/compose-env
New file: ./compose-env

[Unchanged Keys]
Key 'VERSION' value unchanged: '10.2.4'
Key 'AWS_ACCOUNT_ID' value unchanged (both empty)
Key 'DB_PORT' value unchanged: '3306'
Key 'DB_CATALOG' value unchanged: 'querypie'
Key 'LOG_DB_CATALOG' value unchanged: 'querypie_log'
Key 'ENG_DB_CATALOG' value unchanged: 'querypie_snapshot'
Key 'DB_MAX_CONNECTION_SIZE' value unchanged: '20'
Key 'DB_DRIVER_CLASS' value unchanged: 'org.mariadb.jdbc.Driver'
Key 'REDIS_PORT' value unchanged: '6379'
Key 'DAC_SKIP_SQL_COMMAND_RULE_FILE' value unchanged: 'skip_command_config.json'
Key 'CABINET_DATA_DIR' value unchanged: '/data'

[Keys Filled with Original Values]
Key 'AGENT_SECRET' empty value replaced with original: '12345678901234567890123456789012'
Key 'KEY_ENCRYPTION_KEY' empty value replaced with original: 'querypie'
Key 'QUERYPIE_WEB_URL' empty value replaced with original: 'http://172.31.54.186'
Key 'DB_HOST' empty value replaced with original: '172.31.54.186'
Key 'DB_USERNAME' empty value replaced with original: 'querypie'
Key 'DB_PASSWORD' empty value replaced with original: 'xxxxxx'
Key 'REDIS_HOST' empty value replaced with original: '172.31.54.186'
Key 'REDIS_PASSWORD' empty value replaced with original: 'xxxxxx'

✅  Key comparison complete. Proceeding with file operations.

===== File Operations =====

⚙️  About to handle certs directory

Copy certs from ../10.2.4/certs to ./certs
Do you want to proceed? (y/Enter for yes, any other key for no): 
Copying new certs:
  - Source: ../10.2.4/certs
  - Destination: ./certs
  ✓ Successfully copied certs directory


⚙️  About to handle novac-compose.yml

Copy ../10.2.4/novac-compose.yml to ./novac-compose.yml
Do you want to proceed? (y/Enter for yes, any other key for no): 
Created backup: ./novac-compose.yml.backup_20250328095210
Successfully copied ../10.2.4/novac-compose.yml to ./novac-compose.yml


⚙️  About to handle skip_command_config.json

Copy ../10.2.4/skip_command_config.json to ./skip_command_config.json
Do you want to proceed? (y/Enter for yes, any other key for no): 
Created backup: ./skip_command_config.json.backup_20250328095210
Successfully copied ../10.2.4/skip_command_config.json to ./skip_command_config.json

✅  All operations completed successfully
```  

# Detailed Usage Guide

## 1. Pre-execution Requirements

### 1.1 Directory Structure
```
querypie/
├── 10.1.9/              # Previous version directory
│   ├── compose-env      # Previous version environment configuration file
│   ├── certs/           # Certificate directory
│   ├── novac-compose.yml # Nova configuration file
│   └── skip_command_config.json # SQL command skip configuration
└── 10.2.4/              # New version directory
    ├── merge-env.sh     # Script file
    ├── compose-env      # New version environment configuration file
    ├── certs/           # Certificate directory (copied)
    ├── novac-compose.yml # Nova configuration file (copied)
    └── skip_command_config.json # SQL command skip configuration (copied)
```

### 1.2 Required Conditions
- `compose-env` file must exist in the new version directory
- `compose-env` file must exist in the previous version directory
- Script execution permission is required
- The following files must exist in the previous version directory:
  - `certs/` directory
  - `novac-compose.yml`
  - `skip_command_config.json`

## 2. Execution Mode Description

### 2.1 Dry Run Mode (--dry-run)
```bash
./merge-env.sh previous_version --dry-run
```
- Check comparison results without actual file changes
- No backup files created
- Safely preview changes
- Outputs the following information:
  - Unchanged keys
  - Keys to be filled with previous version's values
  - Changed keys
  - Newly added keys
  - Removed keys

### 2.2 Force Update Mode (--force-update)
```bash
./merge-env.sh previous_version --force-update
```
- Force update with previous version's values even if new version has values
- Cannot be used with --dry-run option
- Performs the following operations:
  1. Overwrite new version's values with previous version's values
  2. Keep keys that exist only in new version
  3. Mark keys that exist only in previous version as comments
- Console output shows changes made in force update mode:
  - "(force update mode)" marked in [Changed Keys] section
  - Clearly distinguishes between previous and current values

### 2.3 Actual Execution Mode
```bash
./merge-env.sh previous_version
```
- Perform actual file changes
- Create automatic backups
- Apply changes and output results
- Performs the following operations:
  1. First execution: Copy `compose-env` → `compose-env.backup`
  2. Each execution: Copy `compose-env` → `compose-env.backup.timestamp`
  3. Merge environment configuration values:
     - If key and value both exist: Keep new value
     - If key exists but value is empty: Fill with previous version's value
     - If key exists only in previous version: Mark as comment
  4. Copy additional files:
     - Copy `certs/` directory
     - Copy `novac-compose.yml` (create backup)
     - Copy `skip_command_config.json` (create backup)

### 2.4 Automatic Confirmation Mode (-y)
```bash
./merge-env.sh previous_version -y
```
  - Automatically proceed without user confirmation for all file copies
  - Automatically copy certs, novac-compose.yml, skip_command_config.json files without confirmation messages
```
./merge-env.sh undo
```
- Restore from the last backup file
- `compose-env.backup` file must exist
- Restore all changes to original state

## 3. Output Result Interpretation

### 3.1 Key Comparison Result Categories
1. **Unchanged Keys**
   - List of unchanged keys
   - Values are identical or both empty

2. **Keys Filled with Original Values**
   - List of keys filled with previous version's values
   - Keys that were empty in new version

3. **Changed Keys**
   - List of keys with changed values
   - Values differ between previous and new versions

4. **New Keys**
   - List of keys that exist only in new version
   - New settings not present in previous version

5. **Removed Keys**
   - List of keys that exist only in previous version
   - Settings removed in new version

### 3.2 File Operation Results
1. **certs directory**
   - Display source and destination paths
   - Verify copy success

2. **novac-compose.yml**
   - Backup file creation information
   - Verify copy success

3. **skip_command_config.json**
   - Backup file creation information
   - Verify copy success

### 3.3 Output Format
- Color-coded output for better readability
- Separated sections by category
- Clearly display before/after values of changes
- Use emojis for operation status display
- User confirmation request messages

## 4. Precautions

### 4.1 Before Execution
- Always run in dry run mode first to check changes
- Ensure sufficient disk space (backup file creation)
- Verify execution permissions
- Check existence of required files

### 4.2 During Execution
- Stop immediately if backup file creation fails
- Check for file access permission issues
- Ensure sufficient system resources
- User confirmation required for each file copy

### 4.3 After Execution
- Preserve backup files
- Verify changes
- Can restore using undo mode if problems occur
- Verify normal operation of copied files

## 5. Troubleshooting

### 5.1 Common Issues
1. **Execution Permission Error**
   ```bash
   chmod +x merge-env.sh
   ```

2. **File Not Found Error**
   - Check previous version directory
   - Verify compose-env file existence
   - Verify certs directory existence
   - Verify novac-compose.yml file existence
   - Verify skip_command_config.json file existence

3. **Backup Failure**
   - Check disk space
   - Verify file permissions

### 5.2 Recovery Methods
1. **Undo Execution**
   ```bash
   ./merge-env.sh undo
   ```

2. **Manual Recovery**
   - Manual restore from backup files
   - Use backup files with timestamps
   - Manual restore of certs directory
   - Manual restore of novac-compose.yml
   - Manual restore of skip_command_config.json

