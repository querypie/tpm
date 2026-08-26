# AWS Marketplace 출시 준비 점검

## 결론

현재 AMI의 사전 설치와 `.crt` 로컬 검증 구조는 AWS Marketplace 제출에 사용할 수 있습니다.
QueryPie ACP와 필요한 컨테이너 이미지는 AMI에 포함되고, 구매자 인스턴스의 최초 부팅은 로컬 스크립트로 설치를 재개합니다.
서명된 `.crt` 라이선스는 컨테이너 내부에서 PKI 방식으로 검증되며 실행 중 외부 라이선스 서버에 연결하지 않습니다.

Community Public 제출 전에 아래 공통 차단 항목과 Community 게이트를 해결해야 합니다.
Standard는 준비 자료만 유지하며 별도 검토 전에는 등록하지 않습니다.
Enterprise는 Community가 Public이 된 뒤 Limited 상품과 Private Offer로만 판매합니다.

## 확인된 제품 계약

### 정확한 제품명

제품명은 `QueryPie ACP Community Edition`입니다.
모든 제목과 설명에서 `ACP`를 포함한 전체 제품명을 사용합니다.

### 지속 사용 가능한 Community 제품

QueryPie ACP Community Edition은 평가판, 베타판 또는 기간 제한 체험판이 아닙니다.
지속적으로 사용할 수 있는 별도 제품입니다.
에디션에 적용되는 유일한 용량 제한은 최대 5명의 활성 사용자입니다.

### 가격 모델과 로컬 PKI 검증

QueryPie ACP Community Edition은 무료 BYOL, QueryPie ACP Standard Edition과 QueryPie ACP Enterprise Edition은 유료 AMI Contract 가격 모델을 사용합니다.
Standard 입력값은 준비용 초안이고, Enterprise는 Public Offer 없이 Private Offer만 사용합니다.
모든 에디션은 각 AWS 구매 권리에 맞게 발급된 서명 `.crt` 파일을 런타임 라이선스로 사용합니다.
컨테이너는 포함된 공개 검증 키로 라이선스를 로컬에서 검증합니다.
라이선스 등록 이후 외부 라이선스 서버 또는 판매자 API와 통신하지 않습니다.

AWS 가격 모델과 `.crt` 런타임 라이선스 파일은 별개의 책임입니다.
Private Offer는 BYOL을 지원하지 않으므로 Enterprise를 BYOL로 등록하지 않습니다.

## 차단 항목

### 고정 초기 관리자 비밀번호

QueryPie ACP 공식 설치 문서는 초기 계정 `qp-admin`과 고정 비밀번호 `querypie`를 안내합니다.
AWS는 AMI에 하드코딩된 서비스 비밀번호를 허용하지 않습니다.
웹 애플리케이션의 초기 인증 예외를 사용하려면 인스턴스마다 무작위로 생성한 일회용 비밀번호를 사용하고 첫 로그인 직후 변경해야 합니다.

AMI 최초 부팅 시 임의 비밀번호를 생성하고 안전하게 조회하게 하거나, 인스턴스 고유 값을 검증한 뒤 최초 관리자 계정을 생성하는 흐름으로 변경해야 합니다.
고정 초기 비밀번호는 AMI와 Marketplace 사용 지침에서 모두 제거해야 합니다.

### Community의 동등한 AWS Marketplace paid option

AWS는 BYOL 제품에 대해 동등한 paid version 또는 paid option이 AWS Marketplace에도 제공될 것을 요구합니다.
준비만 된 Standard 상품이나 외부에서 판매되는 라이선스는 활성 AWS Marketplace paid option이 아닙니다.

기존 AWS Marketplace 제품의 인정 여부, Standard의 향후 등록 계획과 최초 90일 완화 규정 적용을 Seller Operations와 확인해야 합니다.
확인 결과가 Community Public 제출 조건과 충돌하면 Public 전환을 중단하고 유료 옵션 일정을 먼저 조정합니다.

### Enterprise Private Offer 선행 조건

AWS Marketplace 판매자가 Private Offer를 발행하려면 판매자 계정에 활성 Public listing이 하나 이상 있어야 합니다.
따라서 Enterprise 준비는 Community가 Public 상태가 된 뒤 시작합니다.

Enterprise는 Limited 상태를 유지하고 대상 구매자 AWS 계정을 allowlist에 추가합니다.
구매자별 가격, 기간, 지급 일정과 법적 조건은 Private Offer에만 설정합니다.
Enterprise 상품을 Public으로 전환하거나 Public Offer를 제공하지 않습니다.

### Marketplace 전용 사용 지침

AWS는 민감 정보 위치, 암호화 구성, 키 교체, 내부 저장소의 백업과 복구, 상태 점검, 할당량과 추가 비용을 포함한 상세 사용 지침을 요구합니다.
Marketplace 입력 필드에는 EC2 인스턴스가 `Running` 상태가 된 시점부터 일반적으로 3분 이내에 `https://<instance-address>:8443/` 접속을 확인하는 절차를 직접 입력합니다.
선택적 진단 절차로 `ec2-user` SSH 접속과 `/usr/local/bin/setup.v2.sh --verify-installation` 실행 방법을 안내합니다.
라이선스 설치 과정은 Marketplace 사용 지침에서 생략하고, 접속 이후의 자세한 설정과 사용 방법은 [QueryPie ACP Community Edition 설치 및 사용 가이드](https://docs.querypie.com/installation/querypie-acp-community-edition)로 안내합니다.

현재 연결 문서는 일반 Linux 설치 명령, 라이선스 등록, 고정 초기 관리자 비밀번호와 평가판처럼 읽힐 수 있는 일부 표현을 함께 포함합니다.
Marketplace AMI 구매자가 설치 명령을 다시 실행하지 않도록 지침에 명시해야 합니다.
Public 제출 전에는 연결 문서의 제품명을 `QueryPie ACP Community Edition`으로 통일하고, 지속 사용 가능한 제품이며 유일한 에디션 제한이 최대 5 active users라는 설명과 충돌하는 표현을 수정해야 합니다.

연결 문서만으로 AWS가 요구하는 민감 정보, 암호화, 키 교체, 백업, 복구, 상태 점검, 할당량, 추가 비용과 업그레이드 정보가 모두 제공되는지도 확인해야 합니다.
부족한 항목은 Marketplace 사용 지침 또는 별도의 공개 운영 문서로 보완하고 실제 Limited 구매 흐름으로 검증합니다.

### 일반적인 3분 이내 접속 기준

`Running` 상태 이후 3분은 일반적인 환경에서 애플리케이션이 접근 가능한 상태가 되는 통상 시간입니다.
현재 최초 부팅 서비스의 600초 제한은 실패 방지를 위한 최대 실행 한도이며 일반적인 준비 시간을 의미하지 않습니다.
Marketplace 문구는 3분을 보장된 제한 시간이나 SLA로 표현하지 않고 `typically`를 사용합니다.
지원할 인스턴스 타입과 초기 출시 리전에서 반복 측정해 통상적인 3분 설명을 뒷받침해야 합니다.

### 제품명과 AMI 설명의 정합성

AWS 점검표는 제품명과 제품 설명이 제출 AMI의 Description과 일치하도록 요구합니다.
현재 Packer 설명은 `QueryPie Suite <version> on Amazon Linux 2023`이고 Marketplace 제목은 `QueryPie ACP <Edition> Edition`입니다.

에디션별 제출 AMI 또는 복사본을 만들고 AMI 이름과 설명에 정확한 제품명, 에디션, 버전, 운영체제를 반영해야 합니다.

## 높은 우선순위 개선 항목

### 기본 볼륨 크기

현재 AMI 루트 볼륨은 32 GiB입니다.
QueryPie ACP 공식 문서는 기본 운영 환경에 100 GiB 이상을 권장합니다.
출시 AMI 기본값을 100 GiB 이상으로 맞추거나 구매자가 시작 단계에서 확장하도록 명확하게 안내해야 합니다.

### 네트워크 노출 최소화

Compose 파일은 MySQL `3306`과 Redis `6379`를 호스트에 바인딩합니다.
Marketplace 보안 그룹에는 이 포트를 포함하지 않고, 호스트 방화벽과 컨테이너 네트워크에서도 외부 노출을 줄이는 것이 좋습니다.
웹과 프록시 포트는 신뢰된 CIDR만 허용해야 합니다.

### TLS 초기 구성

현재 HTTPS `8443`은 기본 인증서를 사용합니다.
운영 제품은 유효한 TLS 인증서를 설치하는 초기 설정 절차와 HTTP 비활성화 절차를 제공해야 합니다.
TLS 인증서와 QueryPie ACP의 `.crt` 라이선스 파일을 문서에서 명확히 구분해야 합니다.

### 민감 정보와 암호화 문서화

현재 최초 부팅은 `AGENT_SECRET`, `KEY_ENCRYPTION_KEY`, `DB_PASSWORD`, `REDIS_PASSWORD`를 무작위로 생성합니다.
이 값, QueryPie ACP 데이터와 `.crt` 라이선스가 저장되는 정확한 경로를 구매자용 지침에 기록해야 합니다.
백업, 복구와 검증용 공개 키 교체 절차도 함께 설명해야 합니다.
Marketplace 소스 스냅샷의 비암호화 요구와 구매자 런타임 EBS 암호화 권장을 구분해서 설명해야 합니다.

## 외부 의존성이 아닌 항목

다음 항목은 구매자 인스턴스의 지속적인 외부 의존성으로 분류하지 않습니다.

- AMI 빌드 단계에서 포함된 `setup.v2.sh`
- AMI 빌드 단계에서 미리 받은 QueryPie ACP 컨테이너 이미지
- 최초 부팅 시 로컬 `setup.v2.sh --resume` 실행
- Community의 자동화된 BYOL `.crt` 발급 절차
- Standard Contract 또는 Enterprise Private Offer 권리를 확인한 뒤 수행하는 `.crt` 발급 절차
- 컨테이너 내부의 로컬 PKI 라이선스 검증

Community의 라이선스 발급 URL은 구매자에게 필요한 일회성 BYOL fulfillment 경로이므로 Marketplace의 BYOL URL 필드에 표시합니다.
라이선스 발급 또는 설치 단계는 Community Marketplace 사용 지침에 반복해서 작성하지 않습니다.
Standard와 Enterprise의 발급 절차는 각각 수락된 Contract 또는 Private Offer 권리를 확인해야 합니다.

## 현재 구현에서 이미 반영된 항목

- HVM과 EBS 기반 AMI 사용
- `x86_64`와 ARM64 빌드 지원
- IMDSv2 요구
- 제출 소스 검사 시 `us-east-1` 확인
- 암호화된 Marketplace 소스 스냅샷과 파일시스템 거부
- SSH 비밀번호 인증과 root 로그인 비활성화
- 구매자에게 SSH key 기반 접근과 `sudo` 권한 제공
- `authorized_keys`, SSH host key, machine ID, 로그, 임시 상태 정리
- 이미지에 저장된 애플리케이션 비밀값 초기화 후 최초 부팅에서 재생성
- QueryPie ACP 컨테이너 이미지의 AMI 빌드 단계 사전 다운로드
- 최초 부팅 설치와 상태 검증 자동화

이 항목들도 AWS Partner Central의 `Test Add Version` 스캔 결과로 최종 확인해야 합니다.

## 공식 근거

- [AMI-based product requirements](https://docs.aws.amazon.com/marketplace/latest/userguide/product-and-ami-policies.html)
- [AMI product checklist](https://docs.aws.amazon.com/marketplace/latest/userguide/aws-marketplace-listing-checklist.html)
- [Creating AMI-based products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-single-ami-products.html)
- [Bring Your Own License pricing](https://docs.aws.amazon.com/marketplace/latest/userguide/BYOL-pricing.html)
- [Contract pricing for AMI products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-contracts.html)
- [Preparing a private offer](https://docs.aws.amazon.com/marketplace/latest/userguide/private-offers-overview.html)
- [Creating and managing private offers](https://docs.aws.amazon.com/marketplace/latest/userguide/creating-private-offer.html)
- [Private offer FAQ](https://docs.aws.amazon.com/marketplace/latest/userguide/private-offer-faq.html)
- [Creating AMI and container product usage instructions](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-container-product-usage-instructions.html)
- [QueryPie ACP Community Edition](https://docs.querypie.com/en/installation/querypie-acp-community-edition)
