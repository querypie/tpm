# Introduction

QueryPie 업그레이드 시 compose-env의 빈 값을 채워주는 스크립트 (from: 이전버전, to: 신규버전)


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
  - 콘솔 출력
  - 원본 compose-env copy to compose-env.backup (최초 한번만 copy)
  - 신규 compose-env copy to compose-env.backup.timestamp (매 실행시 copy)
  - compose-env 값 변경 (신규 compose-env 키 값 기준)
    - 키 o & 값 o : 신규 값 유지
    - 키 o & 값 x : 이전버전에서 값 copy
    - 키 x : 키 삭제로 코멘트 표시 (이전버전에만 존재)
```
./merge-env.sh undo
```   
  - 초기 compose-env 로 원복

## 예시)  10.1.9 -> 10.2.4  (10.2.4 디렉토리에서 실행)
    ./merge-env.sh 10.1.9 --dry-run  

    ./merge-env.sh 10.1.9  

    ./merge-env.sh undo

## 콘솔 출력 내용
```  
./merge-env.sh 10.1.9 --dry-run
Dry run mode: No backup files will be created.
Dry run mode: Output shows comparison results only, no changes made.

===== Key Comparison Results =====
Original file: ../10.1.9/compose-env
New file: ./compose-env

[Unchanged Keys]
Key 'AWS_ACCOUNT_ID' value unchanged (both empty)
Key 'DB_PORT' value unchanged: '3306'
Key 'DB_CATALOG' value unchanged: 'querypie'
Key 'DB_MAX_CONNECTION_SIZE' value unchanged: '20'
Key 'REDIS_PORT' value unchanged: '6379'
Key 'DAC_SKIP_SQL_COMMAND_RULE_FILE' value unchanged: 'skip_command_config.json'
Key 'CABINET_DATA_DIR' value unchanged: '/data'

[Keys Filled with Original Values]
Key 'AGENT_SECRET' empty value replaced with original: '12345678901234567890123456789012'
Key 'KEY_ENCRYPTION_KEY' empty value replaced with original: 'querypie'
Key 'QUERYPIE_WEB_URL' empty value replaced with original: 'http://www.querypie.com'
Key 'DB_HOST' empty value replaced with original: 'xxx.xxx.xxx.xxx'
Key 'DB_USERNAME' empty value replaced with original: 'querypie'
Key 'DB_PASSWORD' empty value replaced with original: 'querypie'
Key 'REDIS_HOST' empty value replaced with original: 'xxx.xxx.xxx.xxx'
Key 'REDIS_PASSWORD' empty value replaced with original: 'querypie'

[Changed Keys]
Key 'VERSION' value changed: [Original:'10.1.9'] -> [New:'10.2.4']
Key 'LOG_DB_CATALOG' value changed: [Original:'${DB_CATALOG}_log'] -> [New:'querypie_log']
Key 'ENG_DB_CATALOG' value changed: [Original:'${DB_CATALOG}_snapshot'] -> [New:'querypie_snapshot']

[New Keys]
Key 'DB_DRIVER_CLASS'=org.mariadb.jdbc.Driver

[Removed Keys]
Key 'COMPOSE_PROJECT_NAME'='querypie'
Key 'NODE_ENV'='production'
Key 'ENABLE_FILE_LOGGING'='true'
Key 'API_JVM_HEAPSIZE'='2g'
Key 'ENG_DB_HOST'='${DB_HOST}'
Key 'ENG_DB_PORT'='${DB_PORT}'
Key 'ENG_DB_USERNAME'='${DB_USERNAME}'
Key 'ENG_DB_PASSWORD'='${DB_PASSWORD}'
Key 'PROXY_PORT_START'='40000'
Key 'PROXY_PORT_END'='40100'
Key 'PROXY_HEALTHCHECK_PORT'='6000'
Key 'PROXY_AGENT_TCP_PORT'='9000'
Key 'PROXY_ENABLE_PROXY_PROTOCOL_V2'='false'
Key 'SQL_JOB'='false'
Key 'SQL_JOB_HOSTNAME'=''
Key 'PROXY_HTTPS_CERT_PATH'=''
Key 'PROXY_HTTPS_CERT_PASSWORD'=''
Key 'PROXY_HTTPS_HOSTNAME'=''
Key 'LOG_DB_HOST'='${DB_HOST}'
Key 'LOG_DB_PORT'='${DB_PORT}'
Key 'LOG_DB_USERNAME'='${DB_USERNAME}'
Key 'LOG_DB_PASSWORD'='${DB_PASSWORD}'
Key 'LOG_DB_MAX_CONNECTION_SIZE'='20'
```  