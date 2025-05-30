# [BETA] QueryPie 유틸리티 스크립트 사용법

이 디렉토리에는 QueryPie 서비스 관리를 위한 스크립트들이 포함되어 있습니다.

베타 버전이며 테스트 용도로만 사용하길 권장합니다.

정식 배포될 시에는 별도 공지와 위치도 변경 됩니다.

## 사전준비 예시
```
- curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/ChangeImages.sh -o ChangeImages.sh
- chmod +x ChangeImages.sh
```

## QueryPieSimpleInstaller.sh  (poc-install.sh 로 이동됨)
- **용도**: QueryPie 서비스의 간편 설치 및 초기 설정
- **다운로드**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPieSimpleInstaller.sh -o QueryPieSimpleInstaller.sh`
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./QueryPieSimpleInstaller.sh <version>`
  - `version`: 버전 번호 (예: 10.2.7)
- **예시**:
  ```bash
  ./QueryPieSimpleInstaller.sh 10.2.7    # 10.2.7 버전의 QueryPie 설치 및 설정
  ``` 

## QueryPie.sh
- **용도**: QueryPie 서비스와 도구들의 실행, 중지, 재시작, 로그 확인
- **다운로드**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPie.sh -o QueryPie.sh`
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./QueryPie.sh <service> <version> <action>`
- **예시**: 
  ```bash
  ./QueryPie.sh querypie 1.0.0 up     # QueryPie 서비스 시작
  ./QueryPie.sh tools 1.0.0 down      # Tools 서비스 중지
  ./QueryPie.sh querypie 1.0.0 log    # QueryPie 로그 확인
  ```

## ChangeImages.sh
- **용도**: QueryPie 도커 이미지 교체 및 서비스 재시작
- **다운로드**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/ChangeImages.sh -o ChangeImages.sh`
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./ChangeImages.sh <version> [--with-tools] [--force-restart] [-h <harbor-address>]`
  - `version`: 버전 번호 (예: 10.2.7)
  - `--with-tools`: QueryPie Tools 이미지도 함께 업데이트
  - `--force-restart`: 이미지 업데이트 여부와 관계없이 서비스 강제 재시작
  - `-h <harbor-address>`: 커스텀 Harbor 레지스트리 주소 (기본값: harbor.chequer.io/querypie)
- **예시**:
  ```bash
  ./ChangeImages.sh 10.2.7                    # QueryPie 이미지만 교체
  ./ChangeImages.sh 10.2.7 --with-tools       # QueryPie와 Tools 이미지 모두 교체
  ./ChangeImages.sh 10.2.7 --force-restart    # QueryPie 이미지 교체 후 강제 재시작
  ./ChangeImages.sh 10.2.7 --with-tools --force-restart  # 모든 이미지 교체 후 강제 재시작
  ./ChangeImages.sh 10.2.7 -h custom.harbor.io/querypie  # 커스텀 Harbor 주소 사용
  ```

## OneStepUpgrade.sh
- **용도**: QueryPie 서비스를 새 버전으로 한 번에 업그레이드
- **다운로드**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/OneStepUpgrade.sh -o OneStepUpgrade.sh`
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./OneStepUpgrade.sh <현재_버전> <새_버전> [-y]`
- **예시**:
  ```bash
  ./OneStepUpgrade.sh 10.2.6 10.2.7    # 10.2.6에서 10.2.7로 업그레이드
  ./OneStepUpgrade.sh 10.2.6 10.2.7 -y  # 자동 승인으로 업그레이드
  ```

## QueryPieDBBackup.sh
- **용도**: QueryPie 데이터베이스 백업 (querypie, querypie_log, querypie_snapshot)
- **다운로드**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPieDBBackup.sh -o QueryPieDBBackup.sh`
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./QueryPieDBBackup.sh <version>`
- **예시**:
  ```bash
  ./QueryPieDBBackup.sh 10.2.7    # 10.2.7 버전의 모든 DB 백업
  ```

## QueryPieDBRestore.sh
- **용도**: QueryPie 데이터베이스 복원 (querypie, querypie_log, querypie_snapshot)
- **다운로드**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPieDBRestore.sh -o QueryPieDBRestore.sh`
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./QueryPieDBRestore.sh <version>`
- **예시**:
  ```bash
  ./QueryPieDBRestore.sh 10.2.7    # 10.2.7 버전의 백업 파일들을 복원
  ```

## QueryPieDownloadImages.sh
- **용도**: QueryPie 도커 이미지를 로컬에 다운로드 (폐쇄망 설치를 위한 이미지 다운로드)
- **다운로드**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPieDownloadImages.sh -o QueryPieDownloadImages.sh`
- **실행 위치**: `이미지 다운로드 받을 장비`
- **사용법**: `./QueryPieDownloadImages.sh <version> [app_name]`
  - app_name: 'querypie' 또는 'tools' (선택 사항, 없으면 둘 다 처리)
- **예시**:
  ```bash
  ./QueryPieDownloadImages.sh 10.2.1          # QueryPie와 Tools 이미지 모두 다운로드
  ./QueryPieDownloadImages.sh 10.2.1 querypie  # QueryPie 이미지만 다운로드
  ./QueryPieDownloadImages.sh 10.2.1 tools     # Tools 이미지만 다운로드
  ```

## QueryPieLoadImages.sh
- **용도**: 로컬에 저장된 QueryPie 도커 이미지를 로드 (QueryPieDownloadImages.sh로 만든 파일과 같이 두고 실행)
- **다운로드**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPieLoadImages.sh -o QueryPieLoadImages.sh`
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./QueryPieLoadImages.sh <version> [app_name]`
  - app_name: 'querypie' 또는 'tools' (선택 사항, 없으면 둘 다 처리)
- **예시**:
  ```bash
  ./QueryPieLoadImages.sh 10.2.1          # QueryPie와 Tools 이미지 모두 로드
  ./QueryPieLoadImages.sh 10.2.1 querypie  # QueryPie 이미지만 로드
  ./QueryPieLoadImages.sh 10.2.1 tools     # Tools 이미지만 로드
  ```

## EnvCheck.sh
- **용도**: compose-env 와 docker-compose.yml 파일 조합으로 만들어진 환경변수 체크
- **다운로드**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/EnvCheck.sh -o EnvCheck.sh`
- **실행 위치**: `{user home} or {version 홈}`
- **사용법**: `./EnvCheck.sh <version> [-o] <filename>`
- **예시**:
  ```bash
  ./EnvCheck.sh 10.2.1          
  ./EnvCheck.sh 10.2.1 -o check.txt
  ```

---

# [BETA] QueryPie Utility Scripts Usage Guide

This directory contains scripts for managing the QueryPie service.

This is a beta version and is recommended for testing purposes only.

The location and distribution method will be changed upon official release.

## Prerequisites Example
```
- curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/ChangeImages.sh -o ChangeImages.sh
- chmod +x ChangeImages.sh
```

## QueryPieSimpleInstaller.sh
- **Purpose**: Easy installation and initial setup of QueryPie service
- **Download**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPieSimpleInstaller.sh -o QueryPieSimpleInstaller.sh`
- **Execution Location**: `{user home} or setup.sh storage location`
- **Usage**: `./QueryPieSimpleInstaller.sh <version>`
  - `version`: Version number (e.g., 10.2.7)
- **Example**:
  ```bash
  ./QueryPieSimpleInstaller.sh 10.2.7    # Install and configure QueryPie version 10.2.7
  ``` 

## QueryPie.sh
- **Purpose**: Start, stop, restart, and check logs for QueryPie services and tools
- **Download**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPie.sh -o QueryPie.sh`
- **Execution Location**: `{user home} or setup.sh storage location`
- **Usage**: `./QueryPie.sh <service> <version> <action>`
- **Example**: 
  ```bash
  ./QueryPie.sh querypie 1.0.0 up     # Start QueryPie service
  ./QueryPie.sh tools 1.0.0 down      # Stop Tools service
  ./QueryPie.sh querypie 1.0.0 log    # Check QueryPie logs
  ```

## ChangeImages.sh
- **Purpose**: Replace QueryPie Docker images and restart services
- **Download**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/ChangeImages.sh -o ChangeImages.sh`
- **Execution Location**: `{user home} or setup.sh storage location`
- **Usage**: `./ChangeImages.sh <version> [--with-tools] [--force-restart] [-h <harbor-address>]`
  - `version`: Version number (e.g., 10.2.7)
  - `--with-tools`: Update QueryPie Tools images as well
  - `--force-restart`: Force restart services regardless of image updates
  - `-h <harbor-address>`: Custom Harbor registry address (default: harbor.chequer.io/querypie)
- **Example**:
  ```bash
  ./ChangeImages.sh 10.2.7                    # Replace QueryPie images only
  ./ChangeImages.sh 10.2.7 --with-tools       # Replace both QueryPie and Tools images
  ./ChangeImages.sh 10.2.7 --force-restart    # Replace QueryPie images and force restart
  ./ChangeImages.sh 10.2.7 --with-tools --force-restart  # Replace all images and force restart
  ./ChangeImages.sh 10.2.7 -h custom.harbor.io/querypie  # Use custom Harbor address
  ```

## OneStepUpgrade.sh
- **Purpose**: One-step upgrade of QueryPie service to a new version
- **Download**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/OneStepUpgrade.sh -o OneStepUpgrade.sh`
- **Execution Location**: `{user home} or setup.sh storage location`
- **Usage**: `./OneStepUpgrade.sh <current_version> <new_version> [-y]`
- **Example**:
  ```bash
  ./OneStepUpgrade.sh 10.2.6 10.2.7    # Upgrade from 10.2.6 to 10.2.7
  ./OneStepUpgrade.sh 10.2.6 10.2.7 -y  # Upgrade with automatic approval
  ```

## QueryPieDBBackup.sh
- **Purpose**: Backup QueryPie databases (querypie, querypie_log, querypie_snapshot)
- **Download**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPieDBBackup.sh -o QueryPieDBBackup.sh`
- **Execution Location**: `{user home} or setup.sh storage location`
- **Usage**: `./QueryPieDBBackup.sh <version>`
- **Example**:
  ```bash
  ./QueryPieDBBackup.sh 10.2.7    # Backup all DBs for version 10.2.7
  ```

## QueryPieDBRestore.sh
- **Purpose**: Restore QueryPie databases (querypie, querypie_log, querypie_snapshot)
- **Download**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPieDBRestore.sh -o QueryPieDBRestore.sh`
- **Execution Location**: `{user home} or setup.sh storage location`
- **Usage**: `./QueryPieDBRestore.sh <version>`
- **Example**:
  ```bash
  ./QueryPieDBRestore.sh 10.2.7    # Restore backup files for version 10.2.7
  ```

## QueryPieDownloadImages.sh
- **Purpose**: Download QueryPie Docker images locally (for offline installation)
- **Download**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPieDownloadImages.sh -o QueryPieDownloadImages.sh`
- **Execution Location**: `Equipment to download images`
- **Usage**: `./QueryPieDownloadImages.sh <version> [app_name]`
  - app_name: 'querypie' or 'tools' (optional, processes both if not specified)
- **Example**:
  ```bash
  ./QueryPieDownloadImages.sh 10.2.1          # Download both QueryPie and Tools images
  ./QueryPieDownloadImages.sh 10.2.1 querypie  # Download QueryPie images only
  ./QueryPieDownloadImages.sh 10.2.1 tools     # Download Tools images only
  ```

## QueryPieLoadImages.sh
- **Purpose**: Load locally stored QueryPie Docker images (run with files created by QueryPieDownloadImages.sh)
- **Download**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/QueryPieLoadImages.sh -o QueryPieLoadImages.sh`
- **Execution Location**: `{user home} or setup.sh storage location`
- **Usage**: `./QueryPieLoadImages.sh <version> [app_name]`
  - app_name: 'querypie' or 'tools' (optional, processes both if not specified)
- **Example**:
  ```bash
  ./QueryPieLoadImages.sh 10.2.1          # Load both QueryPie and Tools images
  ./QueryPieLoadImages.sh 10.2.1 querypie  # Load QueryPie images only
  ./QueryPieLoadImages.sh 10.2.1 tools     # Load Tools images only
  ```

## EnvCheck.sh
- **Purpose**: Check environment variables created by the combination of compose-env and docker-compose.yml files
- **Download**: `curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/EnvCheck.sh -o EnvCheck.sh`
- **Execution Location**: `{user home} or {version 홈}`
- **Usage**: `./EnvCheck.sh <version> [-o] <filename>`
- **Example**:
  ```bash
  ./EnvCheck.sh 10.2.1          
  ./EnvCheck.sh 10.2.1 -o check.txt
  ```

