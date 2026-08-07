# Single AMI 등록 입력값

## 상품 유형과 가격 모델

세 상품의 배포 방식은 `Amazon Machine Image (AMI)`와 `AMI standalone`으로 제안합니다.
현재 `aws/ami/` 구현과 직접 연결되고 별도 CloudFormation 템플릿이 없기 때문입니다.

| 상품 | 제안 가격 모델 | 이유 | 확정할 사항 |
|------|----------------|------|-------------|
| Community | Free | 소프트웨어 요금 없이 최대 5명의 소규모 자체 운영 환경 제공 | Marketplace 실행 시 외부 신청 없이 자동 사용 가능해야 함 |
| Standard | AMI with contract pricing | 1년 단위, 최소 10명의 사용자 기반 라이선스와 가장 잘 맞음 | 계약 차원, 수량, 12개월 가격, entitlement 연동 |
| Enterprise | AMI with contract pricing 및 private offer | 고객별 사용자·사용량·사이트·DR 조건 협상에 적합 | 공개 가격 노출 여부, 계약 차원, private offer 운영 정책 |

Standard나 Enterprise를 BYOL로 등록하면 외부 라이선스 URL을 사용할 수 있지만 AWS Marketplace는 소프트웨어 요금을 청구하지 않습니다.
AWS 통합 청구가 목표라면 BYOL 대신 contract pricing과 AWS entitlement 또는 License Manager 연동을 사용해야 합니다.

## 공통 버전 정보

| 입력 항목 | 제안 또는 현재 값 | 상태 |
|-----------|-------------------|------|
| Version title | 실제 출시 버전, 예: `11.6.5` | 출시 시 확정 |
| Release notes | 해당 버전의 보안, 기능, 수정 사항과 업데이트 중요도 | 작성 필요 |
| Delivery option | `AMI (standalone)` | 제안 확정 |
| Architecture | `x86_64` | 초기 출시 제안 |
| AMI ID | `us-east-1`의 판매자 계정 소유 AMI | 생성 필요 |
| IAM access role ARN | AWS Marketplace가 AMI를 복사·스캔할 수 있는 역할 | 생성 필요 |
| Operating system | `Amazon Linux 2023` | 현재 Packer 기준 |
| OS version | 제출 AMI가 사용한 정확한 AL2023 릴리스 | 빌드 후 기록 |
| OS user name | `ec2-user` | 현재 Packer 기준 |
| Scanning port | `22` | SSH 접근 정책 검증 필요 |
| Recommended instance type | `m7i.xlarge` | 4 vCPU, 16 GiB 기준 제안 |
| Root volume | 100 GiB 이상 권장 | 현재 AMI 기본값 32 GiB와 정합화 필요 |

AWS Marketplace 소스 AMI는 `us-east-1`에 있어야 하고 판매자 계정이 소유해야 합니다.
스냅샷은 암호화되지 않아야 하며 AMI는 HVM과 EBS를 사용해야 합니다.
현재 `aws/ami/`는 기본적으로 `ap-northeast-2`에서 빌드하므로 판매자 계정의 `us-east-1`로 복사하는 승격 절차가 추가로 필요합니다.

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
|----------|------|-----------|------|
| TCP | 22 | 관리자 또는 AWS Marketplace 검사 CIDR | SSH 관리와 스캔 |
| TCP | 8443 | 승인된 사용자 네트워크 | QueryPie 웹 콘솔 |
| TCP | 9000 | 승인된 사용자·에이전트 네트워크 | DAC와 SAC 프록시 |
| TCP | 6443 | 승인된 Kubernetes 사용자 네트워크 | KAC 프록시 |
| TCP | 7447 | 승인된 사용자 네트워크 | WAC 프록시 |
| TCP | 40000-40030 | 승인된 데이터베이스 클라이언트 네트워크 | DAC Agentless 프록시 |

MySQL `3306`, Redis `6379`, tools `8050`은 외부 인바운드 규칙에 포함하지 않습니다.
사용하지 않는 QueryPie 프록시 포트도 열지 않습니다.
AWS Marketplace 스캔에 필요한 최신 내부 CIDR은 제출 시 AWS 포털 안내와 대조합니다.

## Usage instructions에 포함할 내용

AWS는 단순 실행 절차 외에도 다음 내용을 요구합니다.

- 최초 부팅 완료 확인과 애플리케이션 상태 점검 절차
- 웹 콘솔에 접속하고 최초 관리자를 안전하게 생성하는 절차
- 민감 정보 저장 위치
- 암호화 구성과 키 교체 요구 사항
- 내부 데이터 저장소의 구성, 백업, 복구 절차
- 업그레이드 시 데이터와 설정 보존 절차
- AWS 서비스 할당량 관리와 추가 AWS 인프라 비용
- 필수 외부 의존성과 지속적인 외부 연결이 있다면 그 목록과 목적
- 지원 연락처와 장애 진단 자료 수집 방법

현재 구현은 위 항목을 충족하는 Marketplace 전용 사용 지침이 없으므로 Public 출시 전에 별도 문서가 필요합니다.

## 리전과 국가

초기 배포 리전은 실제 검증이 완료된 리전만 선택합니다.
서울 `ap-northeast-2`, 도쿄 `ap-northeast-1`, 버지니아 북부 `us-east-1`을 우선 검증 대상으로 제안합니다.
검증하지 않은 미래 리전을 자동 포함하는 옵션은 초기에는 끄는 것을 권장합니다.

구매 가능 국가는 법무, 세무, 수출 통제, 지원 가능 시간을 기준으로 별도로 정합니다.
상품 언어는 이 국가 설정이나 배포 리전 설정으로 제어되지 않습니다.

## 공개 오퍼

| 입력 항목 | Community | Standard | Enterprise |
|-----------|-----------|----------|------------|
| Pricing | Free | 12개월 contract dimension과 가격 필요 | 공개 계약 차원 또는 private offer 정책 필요 |
| EULA | AWS 표준 계약 또는 Community EULA 결정 | 자체 EULA와 AWS 표준 계약 중 결정 | 협상 가능한 계약 구조와 EULA 결정 |
| Country availability | 판매 가능 국가 확정 | 판매 가능 국가 확정 | 판매 가능 국가 확정 |
| Refund policy | 소프트웨어 요금 없음과 AWS 인프라 요금 제외 명시 | 환불 조건, 기간, 이메일 확정 | private offer 환불·해지 조건과 이메일 확정 |
| Test allowlist | 내부 구매 테스트 계정 | 내부 구매·entitlement 테스트 계정 | 내부 계정과 private offer 테스트 계정 |

모든 유료 상품의 환불 정책에는 환불 조건과 판매자 연락 방법이 포함되어야 합니다.
AWS 인프라 요금은 QueryPie 소프트웨어 환불과 별개임을 명시합니다.

## 공식 근거

- [Creating AMI-based products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-single-ami-products.html)
- [Managing versions for AMI-based products](https://docs.aws.amazon.com/marketplace/latest/userguide/single-ami-versions.html)
- [AMI product pricing](https://docs.aws.amazon.com/marketplace/latest/userguide/pricing-ami-products.html)
- [Creating AMI and container product usage instructions](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-container-product-usage-instructions.html)
- [Regions and countries](https://docs.aws.amazon.com/marketplace/latest/userguide/regions-and-countries.html)
- [Refunds and cancellations](https://docs.aws.amazon.com/marketplace/latest/userguide/refunds.html)
