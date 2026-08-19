# Single AMI 등록 입력값

## 제품 유형, 가격 모델과 등록 상태

세 제품의 배포 방식은 `Amazon Machine Image (AMI)`와 `AMI standalone`을 사용합니다.
현재 `aws/ami/` 구현과 직접 연결되고 별도 CloudFormation 템플릿이 없기 때문입니다.

| 제품 | AWS 가격 모델 | 라이선스 취득 | 등록 상태 |
|------|---------------|---------------|-----------|
| QueryPie ACP Community Edition | BYOL | 자동 발급되는 무료 `.crt` | 먼저 Limited 검증 후 Public 등록 |
| QueryPie ACP Standard Edition | AMI with contract pricing | AWS 구매 권리에 맞는 `.crt` 자동 발급 방식 확정 필요 | 입력값 준비만, 별도 검토 전 생성·제출 금지 |
| QueryPie ACP Enterprise Edition | AMI with contract pricing | 수락된 Private Offer 조건에 맞는 `.crt` | Limited 상품, Private Offer only |

QueryPie ACP Community Edition은 Free Trial 또는 평가판이 아닙니다.
지속적으로 사용할 수 있는 별도 제품이며, 에디션의 유일한 용량 제한은 최대 5명의 활성 사용자입니다.

AWS는 BYOL 라이선스가 유료 또는 무료일 수 있다고 안내합니다.
Community BYOL 제품에는 AWS Marketplace 소프트웨어 가격을 입력하지 않고 license URL을 입력합니다.
Standard와 Enterprise는 AWS Marketplace에서 결제되는 유료 Contract 상품으로 준비합니다.
세 상품 모두 AWS 인프라 비용은 별도입니다.

Community BYOL 제품에는 AWS Marketplace에서 구매할 수 있는 동등한 paid option이 필요합니다.
Standard 준비안이 이 요건을 충족하는지, 최초 출시 후 90일 완화 규정이 어떻게 적용되는지는 Community Public 제출 전에 Seller Operations와 확인합니다.

## Community BYOL URL

| 입력 항목 | 값 |
|-----------|----|
| Pricing model | `Bring your own license (BYOL)` |
| BYOL URL | `[BYOL_LICENSE_URL]` |
| Marketplace software pricing | 입력하지 않음 |
| License delivery | 자동 발급된 서명 `.crt` 파일 |
| Runtime validation | 컨테이너 내부의 로컬 PKI 검증 |
| Ongoing license service connection | 없음 |

BYOL URL은 공개 HTTPS를 사용해야 합니다.
구매자가 판매자 승인을 기다리지 않고 라이선스를 발급받을 수 있어야 합니다.
라이선스에 필요한 고객 정보만 수집하고 결제 정보를 수집하지 않습니다.

## 공통 버전 정보

| 입력 항목 | 제안 또는 현재 값 | 상태 |
|-----------|-------------------|------|
| Version title | `11.5.7`, `11.6.4` | 실제 AMI 준비 상태 확인 필요 |
| Release notes | 해당 버전의 보안, 기능, 수정 사항과 업데이트 중요도 | 작성 필요 |
| Delivery option | `AMI (standalone)` | 확정 |
| Architecture | `x86_64` | 초기 출시 제안 |
| AMI ID | `us-east-1`의 판매자 계정 소유 AMI | 생성 필요 |
| IAM access role ARN | AWS Marketplace가 AMI를 복사하고 스캔할 수 있는 역할 | 생성 필요 |
| Operating system | `Amazon Linux 2023` | 현재 Packer 기준 |
| OS version | 제출 AMI가 사용한 정확한 AL2023 릴리스 | 빌드 후 기록 |
| OS user name | `ec2-user` | 현재 Packer 기준 |
| Scanning port | `22` | SSH 접근 정책 검증 필요 |
| Recommended instance type | `m7i.xlarge` | 4 vCPU, 16 GiB 기준 제안 |
| Root volume | 100 GiB 이상 권장 | 현재 AMI 기본값 32 GiB와 정합화 필요 |

AWS Marketplace 소스 AMI는 `us-east-1`에 있어야 하고 판매자 계정이 소유해야 합니다.
스냅샷은 암호화되지 않아야 하며 AMI는 HVM과 EBS를 사용해야 합니다.
현재 `aws/ami/`는 기본적으로 `ap-northeast-2`에서 빌드하므로 판매자 계정의 `us-east-1`로 복사하는 승격 절차가 필요합니다.

## Endpoint 입력

현재 Compose 설정을 기준으로 다음 값을 제안합니다.

| 입력 항목 | 제안 값 | 비고 |
|-----------|---------|------|
| Protocol | `https` | 운영 환경 권장 |
| Port | `8443` | 현재 Compose HTTPS 바인딩 |
| Relative URL | `/` | 웹 콘솔 시작 경로 |

현재 기본 인증서는 운영용 공인 인증서가 아니므로 Public 출시 전에 TLS 초기 설정 절차를 정리해야 합니다.
HTTP `8000`은 초기 진단 용도로만 사용하고 운영 Endpoint로 권장하지 않습니다.

## Security group 권장값

포털에는 최소 권한의 예시 CIDR을 입력하고, `0.0.0.0/0`을 관리 포트의 기본값으로 사용하지 않습니다.

| 프로토콜 | 포트 | 권장 소스 | 용도 |
|-----------|------|-----------|------|
| TCP | 22 | 관리자 또는 AWS Marketplace 검사 CIDR | SSH 관리와 스캔 |
| TCP | 8443 | 승인된 사용자 네트워크 | QueryPie ACP 웹 콘솔 |
| TCP | 9000 | 승인된 사용자와 에이전트 네트워크 | DAC와 SAC 프록시 |
| TCP | 6443 | 승인된 Kubernetes 사용자 네트워크 | KAC 프록시 |
| TCP | 7447 | 승인된 사용자 네트워크 | WAC 프록시 |
| TCP | 40000-40030 | 승인된 데이터베이스 클라이언트 네트워크 | DAC Agentless 프록시 |

MySQL `3306`, Redis `6379`, tools `8050`은 외부 인바운드 규칙에 포함하지 않습니다.
사용하지 않는 QueryPie ACP 프록시 포트도 열지 않습니다.
AWS Marketplace 스캔에 필요한 최신 내부 CIDR은 제출 시 AWS 포털 안내와 대조합니다.

## Community Usage instructions

Marketplace 입력 필드에는 Community AMI 실행 후 일반적으로 3분 이내에 웹 콘솔 접속을 확인하는 핵심 절차를 직접 입력합니다.
제출 원문은 [Community Usage instructions](products/community/12-usage-instructions.md)에서 관리합니다.

지침의 범위는 다음과 같습니다.

- QueryPie ACP Community Edition AMI를 EC2 인스턴스로 실행
- 신뢰된 접근 네트워크에서 TCP `8443` 인바운드 허용
- EC2 인스턴스가 `Running` 상태가 된 시점부터 일반적으로 3분 이내에 `https://<instance-address>:8443/` 접속
- QueryPie ACP 초기 화면 표시 확인
- 필요한 경우 신뢰된 관리자 네트워크에만 TCP `22`를 허용하고 `ec2-user`로 SSH 접속
- `/usr/local/bin/setup.v2.sh --verify-installation`으로 최초 부팅 서비스, 컨테이너와 애플리케이션 준비 상태 확인

Marketplace 지침에는 라이선스 발급 또는 설치 과정을 포함하지 않습니다.
접속 확인 이후의 자세한 설정과 사용 방법은 [QueryPie ACP Community Edition 설치 및 사용 가이드](https://docs.querypie.com/installation/querypie-acp-community-edition)를 참조하도록 안내합니다.
Marketplace AMI는 사전 설치된 제품이므로 구매자가 연결된 가이드의 일반 Linux 설치 명령을 다시 실행하지 않도록 명시합니다.

AWS는 별도로 민감 정보 위치, 암호화 구성, 암호화 자료 교체, 내부 데이터 저장소의 백업과 복구, 상태 점검, 서비스 할당량, 추가 비용과 업그레이드 지침을 요구합니다.
위 운영 정보는 Marketplace 지침 또는 연결된 공개 문서에서 구매자가 확인할 수 있어야 합니다.
현재 QueryPie ACP Community Edition 설치 문서만으로 이 AWS 전용 운영 정보가 모두 충족되는지는 Public 제출 전에 보완하고 검증해야 합니다.

`Running` 상태 이후 일반적으로 3분 이내 접속 가능하다는 문구는 구매자에게 통상적인 부팅 시간 기대치를 제시합니다.
이 시간은 보장된 제한 시간이나 SLA가 아닙니다.
Public 제출 전에는 지원할 인스턴스 타입과 초기 출시 리전에서 반복 측정해 이 설명을 뒷받침해야 합니다.

## 리전과 국가

초기 배포 리전은 실제 검증이 완료된 리전만 선택합니다.
서울 `ap-northeast-2`, 도쿄 `ap-northeast-1`, 버지니아 북부 `us-east-1`을 우선 검증 대상으로 제안합니다.
검증하지 않은 미래 리전을 자동 포함하는 옵션은 초기에는 끄는 것을 권장합니다.

구매 가능 국가는 법무, 세무, 수출 통제, 지원 가능 시간을 기준으로 별도로 정합니다.
상품 언어는 이 국가 설정이나 배포 리전 설정으로 제어되지 않습니다.

## 상품별 오퍼

| 입력 항목 | QueryPie ACP Community Edition | QueryPie ACP Standard Edition | QueryPie ACP Enterprise Edition |
|-----------|---------------------------------|--------------------------------|----------------------------------|
| Pricing | BYOL, AWS Marketplace 소프트웨어 요금 없음 | AMI Contract, 10/15/20 users 가격 초안 | AMI Contract, 구매자별 협상 가격 |
| Offer | Public Offer | 준비만, 생성·제출 보류 | Private Offer only, Public Offer 없음 |
| Visibility | Limited 검증 후 Public | 별도 검토 전 Partner Central에 생성하지 않음 | Limited 유지, Public 전환하지 않음 |
| License | 자동 발급되는 무료 `.crt`, 최대 5 active users | AWS 구매 권리에 맞는 `.crt` 발급 연결 필요 | 수락된 Private Offer 조건에 맞는 `.crt` |
| EULA | [QueryPie EULA](https://www.querypie.com/eula) | [QueryPie EULA](https://www.querypie.com/eula) | 기본 EULA 또는 Private Offer별 협상 문서 |
| Country availability | Public 판매 가능 국가 확정 필요 | 향후 등록 검토에서 확정 | Private Offer별 geo-targeting 검토 |
| Test allowlist | 내부 실행 테스트 계정 | 향후 Limited 테스트 계정 | 내부 테스트 및 대상 구매자 계정 |

Standard와 Enterprise의 소프트웨어 요금, 환불과 계약 조건은 AWS Marketplace Contract 또는 Private Offer에 반영합니다.
Enterprise 구매자는 상품 allowlist와 Private Offer의 대상 계정에 포함되어야 합니다.
Private Offer는 BYOL을 지원하지 않으므로 Enterprise에 BYOL 가격 모델을 사용하지 않습니다.
AWS 인프라 요금은 별도로 AWS가 청구합니다.
기술지원 정보는 `https://docs.querypie.com/support`에서 제공하고 문의는 `support@querypie.com`으로 받습니다.

## 공식 근거

- [Creating AMI-based products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-single-ami-products.html)
- [Managing versions for AMI-based products](https://docs.aws.amazon.com/marketplace/latest/userguide/single-ami-versions.html)
- [AMI product pricing](https://docs.aws.amazon.com/marketplace/latest/userguide/pricing-ami-products.html)
- [Bring Your Own License pricing](https://docs.aws.amazon.com/marketplace/latest/userguide/BYOL-pricing.html)
- [Contract pricing for AMI products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-contracts.html)
- [Preparing a private offer](https://docs.aws.amazon.com/marketplace/latest/userguide/private-offers-overview.html)
- [Creating and managing private offers](https://docs.aws.amazon.com/marketplace/latest/userguide/creating-private-offer.html)
- [Private offer FAQ](https://docs.aws.amazon.com/marketplace/latest/userguide/private-offer-faq.html)
- [AMI-based product requirements](https://docs.aws.amazon.com/marketplace/latest/userguide/product-and-ami-policies.html)
- [Creating AMI and container product usage instructions](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-container-product-usage-instructions.html)
- [Regions and countries](https://docs.aws.amazon.com/marketplace/latest/userguide/regions-and-countries.html)
