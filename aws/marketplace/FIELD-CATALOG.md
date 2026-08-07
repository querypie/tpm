# AWS Marketplace 입력 항목 카탈로그

## 적용 범위

이 문서는 Single AMI 상품을 AWS Partner Central의 self-service 방식으로 등록할 때 필요한 입력을 정리합니다.
상품 소개 항목은 각 에디션 디렉토리에서 파일별로 관리합니다.
버전, 배포, 공개 오퍼 입력은 [SUBMISSION-FIELDS.md](SUBMISSION-FIELDS.md)에서 관리합니다.

## 상품 소개 정보

AWS Marketplace Catalog API의 신규 Draft 상품 검증 규칙과 AWS 판매자 가이드를 함께 적용했습니다.
AWS 판매자 가이드와 Catalog API의 한도가 다른 경우, 판매자 포털에서 안전하게 사용할 수 있는 더 엄격한 기준을 채택했습니다.

| 입력 항목 | 필수 여부 | 적용 기준 | 파일 |
|-----------|-----------|-----------|------|
| Product title | 필수 | ASCII, 최대 72자, 상품과 에디션을 이름만으로 식별 | `01-product-title.md` |
| SKU | 선택 | 최대 100자, 구매자에게 비노출 | `02-sku.md` |
| Short description | 필수 | API 최대 1,000자, 본 초안은 작성 가이드의 350자 이내 적용 | `03-short-description.md` |
| Long description | 필수 | 최대 5,000자, 기능·효익·사용 방식·구체 정보 포함 | `04-long-description.md` |
| Product logo image URL | 필수 | 공개 S3 HTTPS URL, 투명 또는 흰 배경, 120~640px, 1:1 또는 2:1 | `05-product-logo.md` |
| Highlights | 필수 | 1~3개, 핵심 기능 또는 차별점 | `06-highlights.md` |
| Product categories | 필수 | 1~3개, 관련성이 가장 높은 분류만 사용 | `07-categories.md` |
| Keywords | 필수 | 포털 기준 최대 3개, 전체 250자 이내 | `08-search-keywords.md` |
| Product video URL | 선택 | 공개 HTTPS URL 한 개 | `09-product-video.md` |
| Resources | Draft 생성 시 입력 | 자료명과 공개 HTTPS URL 쌍 | `10-additional-resources.md` |
| Support information | 필수 | 최대 2,000자, 지원 수준과 연락 방법 포함 | `11-support-information.md` |

AWS의 메타데이터 작성 지침에 따라 제목과 제출 원문에는 ASCII 문자만 사용합니다.
한국어 문안은 AWS에 직접 제출하지 않고 한국어 사용 개발자가 영어 원문을 검토하는 데 사용합니다.

## 버전과 AMI 배포 정보

상품 최초 생성 시 다음 정보도 필요합니다.

| 그룹 | 입력 항목 |
|------|-----------|
| Version information | Version title, release notes |
| AMI | AMI ID, IAM access role ARN, OS, OS version, OS user name, scanning port |
| Delivery option | AMI standalone, recommended instance type, usage instructions |
| Endpoint | Protocol, relative URL, port |
| Security group | Protocol, port 범위, 권장 IPv4 CIDR |
| Availability | 배포 가능 AWS 리전, 향후 리전 자동 포함 여부, 허용 인스턴스 타입 |

하나의 Single AMI 상품 버전에는 하나의 AMI가 연결됩니다.
초기 출시는 `x86_64` AMI 하나로 시작하고 ARM64 제공 방식은 별도로 결정하는 것을 권장합니다.

## 공개 오퍼 정보

상품 최초 생성 시 다음 공개 오퍼 정보가 필요합니다.

| 그룹 | 입력 항목 |
|------|-----------|
| Pricing | 가격 모델, 활성 인스턴스 타입별 가격 또는 계약 차원과 기간별 가격 |
| EULA | AWS 표준 계약 사용 여부 또는 다운로드 가능한 자체 EULA URL |
| Country availability | 구매 허용 또는 제외 국가 |
| Refund policy | 소프트웨어 환불 조건과 판매자 연락 방법 |
| Allowlist | Limited 상태에서 테스트할 AWS 계정 ID 목록, 선택 사항 |

AWS 리전은 상품을 배포할 위치이고, 국가는 구매자의 계정 소재지를 의미합니다.
두 값은 별도로 설정해야 합니다.

## 공식 근거

- [Updating AMI-based product information](https://docs.aws.amazon.com/marketplace/latest/userguide/single-ami-updating-product.html)
- [Work with seller products](https://docs.aws.amazon.com/marketplace/latest/developerguide/work-with-seller-products.html)
- [Managing versions for AMI-based products](https://docs.aws.amazon.com/marketplace/latest/userguide/single-ami-versions.html)
- [Creating AMI-based products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-single-ami-products.html)
- [Providing metadata for AWS Marketplace products](https://docs.aws.amazon.com/marketplace/latest/userguide/categories-and-metadata.html)
- [Submitting your product for publication](https://docs.aws.amazon.com/marketplace/latest/userguide/product-submission.html)
