# AWS Marketplace 출시 준비 점검

## 결론

상품 소개 문안은 준비할 수 있지만 현재 AMI와 라이선스 흐름을 그대로 Public 등록하면 AWS 심사에서 차단될 가능성이 높습니다.
아래 `차단` 항목을 해결한 뒤 Limited 상품 생성과 AMI 스캔을 진행해야 합니다.

## 차단 항목

### 외부 라이선스 신청과 개인정보 입력

현재 Community Edition은 별도 신청 폼에 정보를 입력하고 이메일로 라이선스 파일을 받은 뒤 등록해야 합니다.
AWS는 Free 또는 Paid AMI 상품이 추가 라이선스를 요구하지 않고, 구매자가 상품 사용을 위해 이메일 같은 개인정보를 제공하지 않아도 되어야 한다고 명시합니다.

Marketplace 상품 코드 또는 AWS entitlement를 인식해 Community 권리를 자동 활성화해야 합니다.
Standard는 `Standard10Users`, `Standard15Users`, `Standard20Users`를 License Manager에 checkout 요청하고, 응답에 반환된 구매 tier 하나에 따라 각각 10명, 15명, 20명의 활성 사용자 상한을 자동 적용해야 합니다.
Enterprise를 AWS 과금 상품으로 판매하려면 별도의 계약 entitlement를 라이선스 용량과 자동 연동해야 합니다.
외부에서 라이선스를 구매하는 현재 흐름을 유지하려면 BYOL을 선택해야 하지만 AWS Marketplace 소프트웨어 과금은 사용할 수 없습니다.

### 고정 초기 관리자 비밀번호

QueryPie 공식 설치 문서는 초기 계정 `qp-admin`과 고정 비밀번호 `querypie`를 안내합니다.
AWS의 최종 점검표는 기본 사용자가 무작위 비밀번호를 사용하거나 instance ID 같은 인스턴스 고유 값으로 구매자 권한을 확인하도록 요구합니다.

AMI 최초 부팅 시 임의 비밀번호를 생성하고 안전하게 조회하게 하거나, 인스턴스 고유 값을 검증한 뒤 최초 관리자 계정을 생성하는 흐름으로 변경해야 합니다.
고정 초기 비밀번호는 AMI와 사용 지침에서 모두 제거해야 합니다.

### 에디션별 상품 코드와 자동 권리 적용

세 상품이 같은 애플리케이션 이미지를 사용하더라도 AWS Marketplace에서는 서로 다른 상품 코드와 오퍼를 가집니다.
런타임이 EC2 instance identity document의 Marketplace product code와 entitlement를 검증해 Community, Standard, Enterprise 권리를 정확히 적용해야 합니다.
현재 저장소에는 이 연동이 보이지 않으므로 구현과 통합 테스트가 필요합니다.

Standard의 tiered entitlement는 구매 AWS 계정에 발급되며 특정 EC2 인스턴스에 고정되지 않습니다.
계약 기간에는 구매자가 같은 AMI로 여러 인스턴스를 실행할 수 있으므로, 사용자 상한이 설치별인지 구매 계정 전체인지 출시 전에 확정해야 합니다.
구매 계정 전체 상한이라면 여러 인스턴스가 공유하는 별도 라이선스 상태 관리가 필요합니다.

### 상품명과 AMI 설명의 정합성

AWS 점검표는 상품명과 상품 설명이 제출 AMI의 Description과 일치하도록 요구합니다.
현재 Packer 설명은 `QueryPie Suite <version> on Amazon Linux 2023`이고 Marketplace 제목은 `QueryPie ACP <Edition> Edition`입니다.

에디션별 제출 AMI 또는 복사본을 만들고 AMI 이름과 설명에 정확한 상품명, 에디션, 버전, 운영체제를 반영해야 합니다.

### Marketplace 전용 사용 지침

AWS는 민감 정보 위치, 암호화 구성, 키 교체, 내부 저장소의 백업·복구, 상태 점검, 할당량과 추가 비용을 포함한 상세 사용 지침을 요구합니다.
현재 `aws/ami/README.md`는 빌더 운영 문서이고 구매자용 Marketplace 사용 지침이 아닙니다.

에디션별 최초 활성화와 지원 차이를 반영한 영어 사용 지침을 작성하고 실제 Limited 구매 흐름으로 검증해야 합니다.

## 높은 우선순위 개선 항목

### 기본 볼륨 크기

현재 AMI 루트 볼륨은 32 GiB입니다.
QueryPie 공식 문서는 기본 운영 환경에 100 GiB 이상을 권장합니다.
출시 AMI 기본값을 100 GiB 이상으로 맞추거나 구매자가 시작 단계에서 확장하도록 명확하게 안내해야 합니다.

### 네트워크 노출 최소화

Compose 파일은 MySQL `3306`과 Redis `6379`를 호스트에 바인딩합니다.
Marketplace 보안 그룹에는 이 포트를 포함하지 않고, 호스트 방화벽과 컨테이너 네트워크에서도 외부 노출을 줄이는 것이 좋습니다.
웹과 프록시 포트는 신뢰된 CIDR만 허용해야 합니다.

### TLS 초기 구성

현재 HTTPS `8443`은 기본 인증서를 사용합니다.
운영 상품은 유효한 인증서를 설치하는 초기 설정 절차와 HTTP 비활성화 절차를 제공해야 합니다.

### 민감 정보와 암호화 문서화

현재 최초 부팅은 `AGENT_SECRET`, `KEY_ENCRYPTION_KEY`, `DB_PASSWORD`, `REDIS_PASSWORD`를 무작위로 생성합니다.
이 값과 QueryPie 데이터가 저장되는 정확한 경로, 백업 포함 범위, 복구 절차, 키 교체 가능 여부를 구매자용 지침에 기록해야 합니다.
Marketplace 소스 스냅샷의 비암호화 요구와 구매자 런타임 EBS 암호화 권장을 구분해서 설명해야 합니다.

### 외부 의존성 공개

최초 실행이나 라이선스 검증에 QueryPie가 관리하는 외부 서비스가 필요하면 설명 또는 사용 지침에 목적과 연결 대상을 명시해야 합니다.
외부 서비스 중단 시에도 배포와 운영이 어떻게 영향을 받는지 확인해야 합니다.

## 현재 구현에서 이미 반영된 항목

- HVM과 EBS 기반 AMI 사용
- `x86_64`와 ARM64 빌드 지원
- IMDSv2 요구
- 제출 소스 검사 시 `us-east-1` 확인
- 암호화된 Marketplace 소스 스냅샷과 파일시스템 거부
- SSH 비밀번호 인증과 root 로그인 비활성화
- `authorized_keys`, SSH host key, machine ID, 로그, 임시 상태 정리
- 이미지에 저장된 애플리케이션 비밀값 초기화 후 최초 부팅에서 재생성
- 최초 부팅 설치와 상태 검증 자동화

이 항목들도 AWS Partner Central의 `Test 'Add Version'` 스캔 결과로 최종 확인해야 합니다.

## 공식 근거

- [AMI-based product requirements](https://docs.aws.amazon.com/marketplace/latest/userguide/product-and-ami-policies.html)
- [AMI product checklist](https://docs.aws.amazon.com/marketplace/latest/userguide/aws-marketplace-listing-checklist.html)
- [Submitting your product for publication](https://docs.aws.amazon.com/marketplace/latest/userguide/product-submission.html)
- [Best practices for building AMIs](https://docs.aws.amazon.com/marketplace/latest/userguide/best-practices-for-building-your-amis.html)
- [QueryPie ACP Community Edition installation](https://docs.querypie.com/en/installation/querypie-acp-community-edition)
