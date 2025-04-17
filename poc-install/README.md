# QueryPie POC Installer

QueryPie POC 설치를 위한 자동화 스크립트입니다. 이 스크립트는 QueryPie의 POC 환경을 쉽게 설치하고 구성할 수 있도록 도와줍니다.

## 기능

- Single Machine 에 QueryPie 를 설치합니다. 

# 파일명
- poc-install.sh


# 사전 준비
### 신규버전 디렉토리로 이동  

    설치하고자 하는 위치 (ex : 유저홈)

### poc-install.sh 다운로드  

    curl -l https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/poc-install/poc-install.sh -o poc-install.sh

### 실행 권한 추가  

    chmod +x poc-install.sh.sh

### 라이선스 파일 복사  

    제공 받은 license.crt 을 동일 위치로 복사

### Harbor 계정 준비  

    Harbor 에 로그인할 아이디, 비밀번호 준비


## 사용 방법

### 기본 사용법

```bash
./poc-install.sh <version>
```

예시:
```bash
./poc-install.sh 10.2.7
```

### 설치 과정

1. 스크립트 실행
2. Docker 권한 확인 및 설정 (재로그인 필요)
3. Harbor 레지스트리 로그인
4. 환경 변수 설정
5. 데이터베이스 시작
6. 마이그레이션 실행
7. 라이선스 파일 처리
8. QueryPie 시작

---

# QueryPie POC Installer (English)

This is an automated script for installing QueryPie POC. The script helps you easily install and configure the QueryPie POC environment.

## Features

- Installs QueryPie on a Single Machine

# File Name
- poc-install.sh

# Prerequisites
### Move to New Version Directory

    Target installation location (e.g., user home)

### Download poc-install.sh

    curl -l https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/poc-install/poc-install.sh -o poc-install.sh

### Add Execution Permission

    chmod +x poc-install.sh

### Copy License File

    Copy the provided license.crt to the same location

### Prepare Harbor Account

    Prepare Harbor login credentials (username and password)

## Usage

### Basic Usage

```bash
./poc-install.sh <version>
```

Example:
```bash
./poc-install.sh 10.2.7
```

### Installation Process

1. Execute the script
2. Check and configure Docker permissions (requires re-login)
3. Login to Harbor registry
4. Configure environment variables
5. Start the database
6. Run migrations
7. Process license files
8. Start QueryPie

