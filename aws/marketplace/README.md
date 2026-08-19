# QueryPie ACP AWS Marketplace 등록 자료

## 디렉토리 판단

`aws/marketplace/`는 이 자료를 두기에 적절한 위치입니다.
`aws/ami/`는 Marketplace에 제출할 AMI의 빌드와 기술 검증을 담당하고, 이 디렉토리는 판매자 포털에 입력할 상품 메타데이터와 출시 준비 자료를 담당합니다.
두 디렉토리를 `aws/` 아래의 형제 디렉토리로 두면 이미지 제작과 상품 등록의 책임 경계가 분명해집니다.

## 등록 전제

현재 저장소의 구현을 기준으로 세 상품 모두 Single AMI 방식으로 준비합니다.
각 상품은 별도의 AWS Marketplace 상품 ID와 상품 코드를 가져야 합니다.
Community, Standard, Enterprise가 같은 컨테이너 이미지를 사용하더라도 에디션별 가격, 라이선스 권리, 지원 조건이 다르므로 별도 상품으로 관리합니다.
QueryPie ACP Community Edition은 평가판이 아니라 지속적으로 사용할 수 있는 정식 제품이며, 유일한 에디션 한도는 최대 5명의 활성 사용자입니다.

| 상품 | SKU | 가격 모델 | 출시 정책 |
|------|-----|-----------|-----------|
| QueryPie ACP Community Edition | `QP1201E-CDS-AWS` | BYOL | 먼저 Limited 검증을 마치고 Public 등록 |
| QueryPie ACP Standard Edition | `QP1201E-SDS-AWS` | AMI with contract pricing | 유료 상품 자료와 AMI만 준비하고, 별도 검토 전에는 생성·제출하지 않음 |
| QueryPie ACP Enterprise Edition | 미확정 | AMI with contract pricing | Limited 상품을 유지하고 allowlist된 구매자에게 Private Offer로만 판매 |

가격 모델 선택 근거와 대안은 [SUBMISSION-FIELDS.md](SUBMISSION-FIELDS.md)에 정리했습니다.
세 제품의 `.crt` 라이선스 구조와 AWS 가격 모델의 경계는 [LICENSE-FULFILLMENT.md](LICENSE-FULFILLMENT.md)에 정리했습니다.
세 제품의 준비와 출시 순서는 [REGISTRATION-PLAN.md](REGISTRATION-PLAN.md)에 정리했습니다.

## 상품별 입력 파일

각 상품 디렉토리는 AWS Partner Central의 `Update product information` 입력 항목과 일대일로 대응합니다.

```text
products/<edition>/
├── 01-product-title.md
├── 02-sku.md
├── 03-short-description.md
├── 04-long-description.md
├── 05-product-logo.md
├── 06-highlights.md
├── 07-categories.md
├── 08-search-keywords.md
├── 09-product-video.md
├── 10-additional-resources.md
└── 11-support-information.md
```

QueryPie ACP Community Edition의 AMI 실행 지침은 `products/community/12-usage-instructions.md`에서 관리합니다.
QueryPie ACP Standard Edition의 유료 계약 초안은 `products/standard/12-contract-pricing.md`에서 별도로 관리합니다.

영어 섹션은 실제 Marketplace 제출 원문입니다.
한국어 섹션은 한국어 사용 개발자가 영어 원문을 검토하기 위한 번역입니다.
지원 이메일은 `support@querypie.com`이고 기술지원 정보 웹사이트는 `https://docs.querypie.com/support`입니다.
세 상품의 자체 EULA URL은 [QueryPie EULA](https://www.querypie.com/eula)를 사용합니다.
`[PUBLIC_S3_LOGO_URL]` 같은 대괄호 표기는 제출 전에 확정해야 하는 값입니다.

## 공통 문서

- [FIELD-CATALOG.md](FIELD-CATALOG.md): 필수 입력 항목, 제한, 파일 위치
- [LOCALIZATION.md](LOCALIZATION.md): 영어 원문과 AWS 기본 자동 번역 운영 방식
- [LICENSE-FULFILLMENT.md](LICENSE-FULFILLMENT.md): `.crt` 발급·검증과 AWS 가격 모델의 경계
- [SUBMISSION-FIELDS.md](SUBMISSION-FIELDS.md): 버전, AMI, 배포, 가격, EULA, 국가와 리전 입력값
- [REGISTRATION-PLAN.md](REGISTRATION-PLAN.md): Community 우선 등록, Standard 보류, Enterprise Private Offer 계획
- [RELEASE-READINESS.md](RELEASE-READINESS.md): 현재 구현에서 등록 전에 해결해야 할 이슈
- [SOURCES.md](SOURCES.md): AWS와 QueryPie 공식 근거 자료

## 사용 순서

1. Community의 [RELEASE-READINESS.md](RELEASE-READINESS.md) 차단 항목을 해결합니다.
2. Community를 Limited 상태로 만들고 AMI 스캔과 실제 실행을 검증합니다.
3. Community만 Public 전환을 요청합니다.
4. Standard는 상품 자료와 AMI 검증 결과를 준비하되 별도 검토 전에는 Partner Central에 생성·제출하지 않습니다.
5. Community가 Public이 된 뒤 Enterprise를 Limited 상품으로 준비하고, 구매자 allowlist와 Private Offer로만 판매합니다.
