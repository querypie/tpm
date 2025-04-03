# [BETA] QueryPie 유틸리티 스크립트 사용법

이 디렉토리에는 QueryPie 서비스 관리를 위한 스크립트들이 포함되어 있습니다.

베타 버전이며 테스트 용도로만 사용하길 권장합니다.

정식 배포될 시에는 별도 공지와 위치도 변경 됩니다.

## 사전준비 예시
```
- curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/beta/ChangeImages.sh -o ChangeImages.sh
- chmod +x ChangeImages.sh
```

## QueryPie.sh
- **용도**: QueryPie 서비스와 도구들의 실행, 중지, 재시작, 로그 확인
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./QueryPie.sh <service> <version> <action>`
- **예시**: 
  ```bash
  ./QueryPie.sh querypie 1.0.0 up     # QueryPie 서비스 시작
  ./QueryPie.sh tools 1.0.0 down      # Tools 서비스 중지
  ./QueryPie.sh querypie 1.0.0 log    # QueryPie 로그 확인
  ```

## QueryPieDBBackup.sh
- **용도**: QueryPie 데이터베이스 백업 (querypie, querypie_log, querypie_snapshot)
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./QueryPieDBBackup.sh <version>`
- **예시**:
  ```bash
  ./QueryPieDBBackup.sh 10.2.7    # 10.2.7 버전의 모든 DB 백업
  ```

## QueryPieDBRestore.sh
- **용도**: QueryPie 데이터베이스 복원 (querypie, querypie_log, querypie_snapshot)
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./QueryPieDBRestore.sh <version>`
- **예시**:
  ```bash
  ./QueryPieDBRestore.sh 10.2.7    # 10.2.7 버전의 백업 파일들을 복원
  ```

## OneStepUpgrade.sh
- **용도**: QueryPie 서비스를 새 버전으로 한 번에 업그레이드
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./OneStepUpgrade.sh <현재_버전> <새_버전> [-y]`
- **예시**:
  ```bash
  ./OneStepUpgrade.sh 10.2.6 10.2.7    # 10.2.6에서 10.2.7로 업그레이드
  ./OneStepUpgrade.sh 10.2.6 10.2.7 -y  # 자동 승인으로 업그레이드
  ```

## ChangeImages.sh
- **용도**: QueryPie 도커 이미지 교체 및 서비스 재시작
- **실행 위치**: `{유저홈} 혹은 setup.sh 저장 위치`
- **사용법**: `./ChangeImages.sh <version> [--with-tools]`
- **예시**:
  ```bash
  ./ChangeImages.sh 10.2.7             # QueryPie 이미지만 교체
  ./ChangeImages.sh 10.2.7 --with-tools  # QueryPie와 Tools 이미지 모두 교체
  ``` 
