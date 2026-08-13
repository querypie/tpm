# QueryPie ACP AWS Marketplace 등록 자료

## 디렉토리 판단

`aws/marketplace/`는 이 자료를 두기에 적절한 위치입니다.
`aws/ami/`는 Marketplace에 제출할 AMI의 빌드와 기술 검증을 담당하고, 이 디렉토리는 판매자 포털에 입력할 상품 메타데이터와 출시 준비 자료를 담당합니다.
두 디렉토리를 `aws/` 아래의 형제 디렉토리로 두면 이미지 제작과 상품 등록의 책임 경계가 분명해집니다.

## 등록 전제

현재 저장소의 구현을 기준으로 세 상품 모두 Single AMI 방식으로 등록하는 안을 사용합니다.
각 상품은 별도의 AWS Marketplace 상품 ID와 상품 코드를 가져야 합니다.
Community, Standard, Enterprise가 같은 컨테이너 이미지를 사용하더라도 에디션별 가격, 라이선스 권리, 지원 조건이 다르므로 별도 상품으로 관리합니다.

| 상품 | SKU | 가격 모델 | 상태 |
|------|-----|-----------|------|
| QueryPie ACP Community Edition | `QP1201E-CDS-AWS` | Free | 라이선스 자동화 선행 필요 |
| QueryPie ACP Standard Edition | `QP1201E-SDS-AWS` | AMI with contract pricing | 10/15/20 users tier와 12개월 선불 가격 확정, 권리 연동 필요 |
| QueryPie ACP Enterprise Edition | 미확정 | AMI with contract pricing 및 private offer | 계약 차원, 지원 범위, 공개 가격 정책 확정 필요 |

가격 모델 선택 근거와 대안은 [SUBMISSION-FIELDS.md](SUBMISSION-FIELDS.md)에 정리했습니다.
Standard Edition의 계약 차원과 구매·실행 흐름은 [products/standard/12-contract-pricing.md](products/standard/12-contract-pricing.md)에 정리했습니다.
Community Edition과 Standard Edition의 최종 등록 순서는 [REGISTRATION-PLAN.md](REGISTRATION-PLAN.md)에 정리했습니다.

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

Standard의 계약 가격은 `products/standard/12-contract-pricing.md`에서 별도로 관리합니다.

영어 섹션은 실제 Marketplace 제출 원문입니다.
한국어 섹션은 한국어 사용 개발자가 영어 원문을 검토하기 위한 번역입니다.
지원 이메일은 `support@querypie.com`이고 기술지원 정보 웹사이트는 `https://docs.querypie.com/support`입니다.
세 상품의 자체 EULA URL은 [QueryPie EULA](https://www.querypie.com/eula)를 사용합니다.
`[PUBLIC_S3_LOGO_URL]` 같은 대괄호 표기는 제출 전에 확정해야 하는 값입니다.

## 공통 문서

- [FIELD-CATALOG.md](FIELD-CATALOG.md): 필수 입력 항목, 제한, 파일 위치
- [LOCALIZATION.md](LOCALIZATION.md): 영어 원문과 AWS 기본 자동 번역 운영 방식
- [SUBMISSION-FIELDS.md](SUBMISSION-FIELDS.md): 버전, AMI, 배포, 가격, EULA, 국가와 리전 입력값
- [REGISTRATION-PLAN.md](REGISTRATION-PLAN.md): Community와 Standard의 최종 상품 등록 계획
- [RELEASE-READINESS.md](RELEASE-READINESS.md): 현재 구현에서 등록 전에 해결해야 할 이슈
- [SOURCES.md](SOURCES.md): AWS와 QueryPie 공식 근거 자료

## 사용 순서

1. [RELEASE-READINESS.md](RELEASE-READINESS.md)의 차단 항목을 해결합니다.
2. [REGISTRATION-PLAN.md](REGISTRATION-PLAN.md)의 상품, SKU, 버전, 가격 차원을 기준으로 등록합니다.
3. 상품별 입력 파일의 영어 문안을 AWS Partner Central에 입력합니다.
4. 상품을 Limited 상태로 만든 뒤 영어 원문과 AWS 자동 번역이 정상적으로 노출되는지 확인합니다.
5. AMI 스캔과 실제 구매·실행 테스트를 마친 뒤 Public 전환을 요청합니다.
