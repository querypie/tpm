# QueryPie ACP AWS Marketplace 등록 계획

## 결정

상품 준비와 출시는 다음 순서로 분리합니다.

1. QueryPie ACP Community Edition을 먼저 Limited로 검증하고 Public 등록합니다.
2. QueryPie ACP Standard Edition은 유료 상품 메타데이터, 가격 차원, AMI와 검증 자료까지만 준비합니다. 별도 사업·기술 검토가 승인되기 전에는 Partner Central에서 상품을 생성하거나 제출하지 않습니다.
3. QueryPie ACP Enterprise Edition은 Community가 Public이 된 뒤 Limited 상품으로 준비하고, allowlist된 구매자에게 Private Offer로만 판매합니다. Public 전환과 Public Offer는 사용하지 않습니다.

Community의 Public 등록은 Enterprise Private Offer 발행에 필요한 판매자 계정의 활성 Public listing 선행 조건도 충족합니다.

## 상품 구조

| 상품 | Product SKU | AWS 가격 모델 | 현재 단계 | 최종 판매 채널 |
|------|-------------|---------------|-----------|----------------|
| QueryPie ACP Community Edition | `QP1201E-CDS-AWS` | BYOL | 등록·검증 진행 | Public listing |
| QueryPie ACP Standard Edition | `QP1201E-SDS-AWS` | AMI with contract pricing | 자료와 AMI 준비만 수행 | 추후 검토 후 결정 |
| QueryPie ACP Enterprise Edition | 미확정 | AMI with contract pricing | Community Public 이후 Limited로 준비 | Private Offer only |

세 상품은 제품명, 가격, 권리, 지원 조건과 판매 채널이 다르므로 별도 Product ID, Product code와 SKU를 사용합니다.
같은 QueryPie ACP 컨테이너 이미지를 사용하더라도 에디션별 제출 AMI를 별도 자산으로 관리합니다.

## 라이선스 발급과 검증

모든 에디션은 서명된 `.crt` 라이선스 파일을 QueryPie ACP 웹 콘솔에 등록하고, 컨테이너 내부의 공개 검증 키로 PKI 서명을 로컬에서 검증합니다.
라이선스 서명 private key는 AMI, 컨테이너 이미지 또는 구매자 인스턴스에 포함하지 않습니다.
라이선스 등록 이후 제품 실행에는 외부 라이선스 서버 연결이 필요하지 않습니다.

AWS 가격 모델과 `.crt` 런타임 라이선스 파일은 서로 다른 책임입니다.

- Community는 BYOL URL에서 무료 `.crt`를 자동 발급합니다.
- Standard는 AWS Marketplace Contract 권리를 확인한 뒤 해당 권리의 `.crt`를 자동 발급하는 연결 방식을 등록 검토 전에 확정해야 합니다.
- Enterprise는 구매자가 수락한 Private Offer 조건에 맞춰 `.crt`를 발급합니다. Private Offer는 BYOL을 지원하지 않으므로 Enterprise를 BYOL 상품으로 등록하지 않습니다.

세부 경계는 [LICENSE-FULFILLMENT.md](LICENSE-FULFILLMENT.md)를 따릅니다.

## 공통 AMI 준비

등록 또는 Private Offer에 사용할 AMI는 다음 조건을 충족해야 합니다.

- 판매자 계정의 `us-east-1`에 존재합니다.
- QueryPie ACP와 필요한 컨테이너 이미지를 포함합니다.
- 최초 부팅은 AMI에 포함된 로컬 스크립트로 설치를 재개하며 외부 설치 스크립트를 내려받지 않습니다.
- EBS snapshot과 파일시스템은 암호화되지 않습니다.
- HVM, EBS-backed, x86-64 또는 64-bit ARM 아키텍처를 사용합니다.
- AMI Name과 Description에 정확한 제품명, 에디션, 버전과 OS를 기록합니다.
- 고정 비밀번호, 자격 증명, SSH authorized key 또는 라이선스 서명 private key를 포함하지 않습니다.
- 구매자에게 SSH key 기반 접근과 `sudo` 권한을 제공합니다.
- `Test Add Version` 스캔을 문제없이 통과합니다.

각 상품에는 실제로 준비되고 검증된 버전만 추가합니다.
Version title은 에디션이나 라이선스 권리를 구분하는 용도로 사용하지 않습니다.

## 1단계: Community 우선 등록

1. Community 메타데이터, SKU, BYOL URL, EULA, 지원 정보와 국가 범위를 확정합니다.
2. 판매자 계정 `us-east-1`에 검증할 Community AMI를 준비합니다.
3. 첫 버전과 AMI standalone deployment를 입력해 Limited 상품을 생성합니다.
4. 내부 구매 계정을 allowlist에 추가하고 `Test Add Version`과 보안 스캔을 완료합니다.
5. Marketplace 전용 사용 지침으로 EC2 실행, 최초 관리자 설정과 무료 `.crt` 발급·등록을 검증합니다.
6. 라이선스 등록 이후 외부 라이선스 서버 연결 없이 최대 5 active users 권리가 적용되는지 확인합니다.
7. 영어 원문과 AWS 자동 번역을 검수합니다.
8. Community만 Public 전환을 요청합니다.

### Community Public 제출 게이트

- 평가판이 아니라 지속 사용 가능한 정식 Community 제품으로 설명됩니다.
- 유일한 에디션 용량 제한이 최대 5 active users로 명시됩니다.
- 무료 `.crt` 발급이 자동화되고 별도의 판매자 승인을 기다리지 않습니다.
- 공통 초기 관리자 비밀번호를 사용하지 않습니다.
- Marketplace 전용 사용 지침이 실행, 라이선스 등록, 상태 확인, 백업, 복구와 업그레이드를 설명합니다.
- BYOL 제품에 필요한 동등한 AWS Marketplace paid option과 적용 시점을 Seller Operations와 확인했습니다.
- 실제 AMI 소유권, 이름, Description과 스캔 결과를 확인했습니다.

위 항목이 해결되기 전에는 Community Public 전환 요청을 제출하지 않습니다.

## 2단계: Standard 상품 준비만 수행

Standard는 유료 AMI Contract 상품 초안을 유지합니다.
현재 단계에서는 다음 준비 작업만 수행합니다.

- Product SKU `QP1201E-SDS-AWS`와 상품 메타데이터 유지
- 10/15/20 users 계약 차원과 12개월 가격 초안 유지
- 제출 후보 AMI 생성, 구조 검증과 보안 스캔 사전 점검
- Marketplace 전용 사용 지침과 지원·환불 문안 준비
- AWS Contract 권리와 오프라인 `.crt` 발급을 연결하는 기술 설계 및 통합 테스트 계획 수립

다음 작업은 별도 검토 승인 전까지 수행하지 않습니다.

- Partner Central에서 Standard 상품 생성
- 버전 또는 가격 정보 제출
- Limited 또는 Public 전환 요청
- 실제 판매 시작

검토 시 가격, 사용자 권리 범위, 다중 인스턴스 정책, 라이선스 발급 연결과 구매 국가를 다시 확정합니다.

## 3단계: Enterprise Private Offer only

Community가 Public 상태가 되어 판매자 계정의 Private Offer 발행 자격을 충족한 뒤 Enterprise를 준비합니다.

1. Enterprise SKU, 계약 차원, EULA, 지원 범위와 Private Offer 승인 절차를 확정합니다.
2. Enterprise AMI와 메타데이터로 Limited 상품을 생성합니다.
3. 대상 구매자 AWS 계정을 상품 allowlist에 추가합니다.
4. 해당 상품을 선택해 구매자별 가격, 기간, 지급 일정과 법적 조건을 담은 Private Offer를 발행합니다.
5. 구매자가 Private Offer를 수락한 뒤 AMI 실행과 계약 권리의 `.crt` 발급·검증을 확인합니다.

Enterprise 상품은 Public으로 전환하지 않으며 Public Offer나 공개 가격을 제공하지 않습니다.
Private Offer는 BYOL을 지원하지 않으므로 Enterprise의 AWS 가격 모델은 AMI Contract를 사용합니다.
새 리전이나 인스턴스 타입을 기존 계약에 제공할 때는 AWS Private Offer 제약을 다시 확인합니다.

## 남은 결정

- Community의 실제 BYOL license URL
- Community BYOL의 동등한 Marketplace paid option 인정 범위와 90일 적용 여부
- Standard 등록 재검토 시점과 승인자
- Standard Contract 권리에서 `.crt`를 자동 발급하는 연결 방식
- Standard의 다중 EC2 인스턴스 사용자 상한 적용 범위
- Enterprise Product SKU, 계약 차원과 Private Offer 운영 승인 절차
- 상품별 구매 가능 국가, 환불 조건과 실제 제출 AMI 버전

## 공식 근거

- [Creating AMI-based products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-single-ami-products.html)
- [Bring Your Own License pricing](https://docs.aws.amazon.com/marketplace/latest/userguide/BYOL-pricing.html)
- [Contract pricing for AMI products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-contracts.html)
- [Preparing a private offer](https://docs.aws.amazon.com/marketplace/latest/userguide/private-offers-overview.html)
- [Creating and managing private offers](https://docs.aws.amazon.com/marketplace/latest/userguide/creating-private-offer.html)
- [Supported product types for private offers](https://docs.aws.amazon.com/marketplace/latest/userguide/private-offers-supported-product-types.html)
- [Private offer FAQ](https://docs.aws.amazon.com/marketplace/latest/userguide/private-offer-faq.html)
