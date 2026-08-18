# QueryPie ACP 라이선스 발급과 로컬 검증

## 적용 범위

이 문서는 QueryPie ACP의 서명 `.crt` 라이선스 파일과 AWS Marketplace 가격 모델의 경계를 정의합니다.
애플리케이션이 `.crt`를 사용한다는 사실만으로 AWS Marketplace 가격 모델이 BYOL이 되는 것은 아닙니다.

| 제품 | AWS 가격 모델 | `.crt` 발급 기준 | 출시 정책 |
|------|---------------|------------------|-----------|
| QueryPie ACP Community Edition | BYOL | 공개 HTTPS BYOL URL에서 무료 자동 발급 | 먼저 Public 등록 |
| QueryPie ACP Standard Edition | AMI with contract pricing | AWS Contract 권리를 확인해 자동 발급하는 방식 확정 필요 | 자료와 AMI 준비만 수행 |
| QueryPie ACP Enterprise Edition | AMI with contract pricing | 구매자가 수락한 Private Offer 조건 | Private Offer only |

Private Offer는 BYOL 가격 모델을 지원하지 않습니다.
따라서 Enterprise의 `.crt`는 Private Offer로 구매한 권리를 제품에 적용하는 런타임 라이선스 파일이며, Marketplace 외부 구매를 전제로 한 BYOL 라이선스가 아닙니다.

## 공통 PKI 검증

모든 에디션은 서명된 `.crt` 라이선스 파일을 QueryPie ACP 웹 콘솔에 등록합니다.
QueryPie ACP 컨테이너는 포함된 공개 검증 키로 라이선스 서명과 에디션별 권리를 로컬에서 검증합니다.

라이선스 서명 private key는 AMI, 컨테이너 이미지 또는 구매자 인스턴스에 포함하지 않습니다.
라이선스 등록 이후 제품 실행에는 외부 라이선스 서버, 판매자 API 또는 다른 클라우드 서비스 연결이 필요하지 않습니다.

`.crt` 라이선스 파일은 QueryPie ACP 제품 권리를 나타내는 서명 파일입니다.
HTTPS endpoint에 사용하는 TLS 인증서와는 별개의 파일입니다.

## Community BYOL 발급

1. 구매자가 AWS Marketplace에서 Community AMI를 구독합니다.
2. 구매자가 공개 HTTPS BYOL URL에서 무료 라이선스 발급 절차를 진행합니다.
3. 발급 시스템이 판매자 수동 승인 없이 서명된 `.crt`를 자동으로 제공합니다.
4. 구매자가 `.crt`를 웹 콘솔에 등록합니다.
5. 컨테이너가 서명을 로컬에서 검증하고 최대 5 active users 권리를 적용합니다.

실제 제출 전 `[BYOL_LICENSE_URL]`을 확정된 공개 HTTPS URL로 교체합니다.
발급 화면은 라이선스에 필요한 최소 고객 정보만 수집하고 결제 정보를 수집하지 않습니다.

## Standard Contract 연결

Standard는 AWS Marketplace 유료 Contract 상품으로 준비합니다.
AWS가 제공하는 구매 권리를 확인한 뒤 선택한 10/15/20 users 권리에 맞는 `.crt`를 자동 발급해야 합니다.

다음 항목을 별도 등록 검토 전에 확정합니다.

- AWS Contract entitlement를 검증하는 주체와 시점
- 검증된 entitlement에서 `.crt` 권리로 변환하는 규칙
- 갱신, 만료, tier 변경과 다중 인스턴스 처리
- 발급 실패와 권리 불일치 시 활성화 차단 방식
- 실제 Limited 통합 테스트 절차

이 연결이 구현·검증되기 전에는 Standard 상품을 Partner Central에 생성하거나 제출하지 않습니다.

## Enterprise Private Offer 연결

Enterprise는 Limited AMI 상품에서 구매자별 Private Offer로만 판매합니다.
구매자가 오퍼를 수락하면 협의된 사용자 또는 사용량, 사이트, 재해 복구와 지원 범위에 맞는 `.crt`를 발급합니다.

Enterprise 발급 절차는 다음을 보장해야 합니다.

- 수락된 Private Offer와 구매자 AWS 계정을 확인합니다.
- 오퍼의 유효 기간과 협의된 권리를 `.crt`에 정확히 반영합니다.
- Private Offer가 없거나 만료·취소되었거나 구매자 정보가 일치하지 않으면 발급하지 않습니다.
- 발급 후 런타임 검증은 컨테이너 내부에서 오프라인으로 수행합니다.

## 구매자 문서 요구 사항

Marketplace 전용 사용 지침에는 다음 내용을 명시합니다.

- AMI에 QueryPie ACP와 필요한 컨테이너 이미지가 사전 설치되어 있음
- 구매자가 외부 설치 스크립트를 실행하지 않음
- 해당 에디션의 라이선스 발급 조건과 `.crt` 등록 절차
- 컨테이너 내부의 로컬 PKI 검증
- 실행 중 외부 라이선스 서버 연결이 없음
- 라이선스 파일의 저장, 교체, 갱신, 백업과 복구 절차
- 라이선스 검증용 공개 키의 교체 정책
- 라이선스 서명 private key가 구매자 환경에 제공되지 않음

## 공식 근거

- [AMI product pricing](https://docs.aws.amazon.com/marketplace/latest/userguide/pricing-ami-products.html)
- [Bring Your Own License pricing](https://docs.aws.amazon.com/marketplace/latest/userguide/BYOL-pricing.html)
- [Contract pricing for AMI products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-contracts.html)
- [Preparing a private offer](https://docs.aws.amazon.com/marketplace/latest/userguide/private-offers-overview.html)
- [AMI-based product requirements](https://docs.aws.amazon.com/marketplace/latest/userguide/product-and-ami-policies.html)
