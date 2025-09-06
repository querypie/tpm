# Tencent Cloud CLI 도구

macOS에서 Tencent Cloud CLI (TCCLI) 작업을 위한 도구입니다.

## 빠른 시작

```bash
# TCCLI 환경 설치
./setup-tccli

# 환경 활성화
source .venv/bin/activate
```

설정 스크립트는 격리된 Python 가상환경 (`.venv`)을 생성하고 TCCLI를 자동으로 설치합니다.

## 사전 요구사항

- Python 3.x with venv 모듈 (pip는 venv에 포함됨)

## 사용법

```bash
# TCCLI 환경 설치 (한 번만 실행)
./setup-tccli

# 환경 활성화
source .venv/bin/activate

# 환경 비활성화
deactivate
```

## 구성

API 자격 증명으로 TCCLI를 구성하세요:

```bash
tccli configure
```

Tencent Cloud API 자격 증명을 입력하세요:
- **secretId**: API SecretId
- **secretKey**: API SecretKey  
- **region**: 대상 지역 (예: `ap-guangzhou`, `ap-seoul`, `ap-tokyo`)
- **output**: 출력 형식 (`json`, `table`, `text`)

## 일반적인 명령어

```bash
# CVM 인스턴스 목록 조회
tccli cvm DescribeInstances

# 특정 지역의 인스턴스 조회
tccli cvm DescribeInstances --region ap-seoul

# VPC 목록 조회
tccli vpc DescribeVpcs
```

## 주요 지역

- `ap-guangzhou`: 광저우
- `ap-seoul`: 서울
- `ap-tokyo`: 도쿄
- `ap-singapore`: 싱가포르
- `na-siliconvalley`: 실리콘밸리

## 문제 해결

### venv 모듈을 찾을 수 없음
```bash
brew install python
```

### 환경 재설정
```bash
rm -rf .venv
./setup-tccli
```

### 권한 문제
```bash
chmod +x setup-tccli
```

## 참고 자료

- [Tencent Cloud CLI 문서](https://www.tencentcloud.com/document/product/1080/38762)
- [Cloud Access Management - API Keys](https://console.tencentcloud.com/cam/capi)
