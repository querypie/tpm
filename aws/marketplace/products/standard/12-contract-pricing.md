# Contract pricing

## 결정

QueryPie ACP Standard Edition은 `AMI with contract pricing`과 tiered entitlement를 사용합니다.
AWS Marketplace Product SKU는 `QP1201E-SDS-AWS` 하나만 사용합니다.
구매자는 12개월 계약을 생성할 때 10, 15, 20 users 중 하나를 선택합니다.
10 users는 최저 기본 플랜이지만 AWS 구매 화면에서 자동 선택되는 값으로 가정하지 않습니다.

## AWS 입력값

| Field | Value |
|-------|-------|
| Product SKU | `QP1201E-SDS-AWS` |
| Pricing model | `AMI with contract pricing` |
| License model | `Tiered` |
| Contracts category | `Users` |
| Contract duration | `12 months` |
| Billing | 12개월 사용료 선불 |
| Unit price basis | 사용자 1명당 연간 `USD 600`, 관련 세금 별도 |
| Contracts Dimension Allow Multiple Purchases | `false` |
| Contracts Dimension Quantity | `1` |

| API name | Display name | Description | Entitlement unit | 12-month rate |
|----------|--------------|-------------|------------------|---------------|
| `Standard10Users` | `Standard 10 Users` | `QueryPie ACP Standard Edition for up to 10 active users` | `None` | `6000.000 USD` |
| `Standard15Users` | `Standard 15 Users` | `QueryPie ACP Standard Edition for up to 15 active users` | `None` | `9000.000 USD` |
| `Standard20Users` | `Standard 20 Users` | `QueryPie ACP Standard Edition for up to 20 active users` | `None` | `12000.000 USD` |

세 API name은 Public 출시 후 변경하지 않습니다.
세 tier 모두 같은 계약 기간을 제공해야 합니다.
12-month rate에는 숫자 금액을 Product Load Form 또는 Partner Central이 요구하는 형식으로 입력합니다.
사용자 수별 파생 SKU와 `QP1201E-SAS-AWS`는 AWS Marketplace에 등록하지 않습니다.

Public Listing에는 세전 소프트웨어 가격을 USD로 입력합니다.
VAT, GST, 판매세 같은 간접세의 계산, 징수, 청구 주체는 구매자 국가와 거래 조건에 따라 달라지므로 VAT를 별도 계약 차원으로 추가하지 않습니다.
상품과 계약 문안에는 `Applicable taxes are additional and handled according to AWS Marketplace tax rules.`를 사용합니다.
세금 처리는 AWS Marketplace Seller Tax Grid와 QueryPie 세무 검토 결과를 따릅니다.

## 애플리케이션 권리 적용

QueryPie는 최초 부팅과 정기 검증 시 AWS Marketplace가 발급한 License Manager 라이선스를 확인합니다.
애플리케이션은 `CheckoutLicense` 요청에 세 entitlement name을 모두 전달하고 응답에 포함된 하나의 tier를 적용합니다.

| 반환된 entitlement | 적용할 활성 사용자 상한 |
|---------------------|-------------------------|
| `Standard10Users` | 10 |
| `Standard15Users` | 15 |
| `Standard20Users` | 20 |

유효한 entitlement가 없거나 만료되면 Standard Edition을 활성화하지 않습니다.
외부 신청 폼, 이메일 입력 또는 별도 라이선스 파일 업로드를 요구하지 않습니다.
EC2 인스턴스 프로파일에는 최소한 다음 작업이 필요합니다.

- `license-manager:CheckoutLicense`
- `license-manager:GetLicense`
- `license-manager:ListReceivedLicenses`

AWS 공식 예시는 갱신과 반환을 위해 `ExtendLicenseConsumption`과 `CheckInLicense`도 포함합니다.
실제 런타임 호출 방식이 확정되면 사용하는 작업만 남겨 최소 권한 정책으로 검증합니다.

## 구매 및 EC2 실행 흐름

1. 구매자가 QueryPie ACP Standard Edition의 Public 상품에서 `Continue to Subscribe`를 선택합니다.
2. 12개월 계약과 자동 갱신 여부를 선택합니다.
3. Contract options에서 `Standard 10 Users`, `Standard 15 Users`, `Standard 20 Users` 중 하나를 선택하고 계약을 생성합니다.
4. AWS Marketplace가 구매자 계정의 License Manager에 선택한 tier의 라이선스를 생성할 때까지 기다립니다. 처리에는 최대 10분이 걸릴 수 있습니다.
5. `Continue to Configuration`에서 AMI delivery method, QueryPie 버전, AWS 리전을 선택합니다.
6. `Continue to Launch`에서 1-Click 또는 EC2 Console을 선택합니다.
7. EC2 Console을 사용하는 경우 인스턴스 타입, VPC, 서브넷, 보안 그룹, 키 페어, EBS를 설정하고 Marketplace AMI로 인스턴스를 생성합니다.
8. 인스턴스에 License Manager 조회 권한이 있는 IAM instance profile을 연결합니다.
9. QueryPie 최초 부팅 서비스가 entitlement를 확인하고 구매한 활성 사용자 상한을 적용합니다.

계약 라이선스는 특정 EC2 인스턴스에 고정되지 않으며 계약 기간에는 같은 AMI로 여러 인스턴스를 실행할 수 있습니다.
따라서 10, 15, 20 users가 설치별 상한인지 구매 AWS 계정 전체 상한인지 별도로 확정해야 합니다.
구매 계정 전체 상한이면 여러 인스턴스가 공통 상태를 확인하는 라이선스 제어가 추가로 필요합니다.

## 검증 기준

- Limited 상품에서 세 tier가 동시에 노출되고 구매자가 하나만 선택할 수 있습니다.
- 각 tier 구매 후 License Manager에 예상 API name의 라이선스가 생성됩니다.
- 10, 15, 20 users 상한이 각각 적용됩니다.
- entitlement가 없거나 만료되면 Standard Edition이 활성화되지 않습니다.
- 계약 변경으로 상위 tier를 선택하면 QueryPie가 갱신된 권리를 반영합니다.
- AMI 버전과 리전을 선택해 EC2 인스턴스를 정상 생성할 수 있습니다.

## 공식 근거

- [Contract pricing for AMI products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-contracts.html)
- [Product pricing](https://docs.aws.amazon.com/marketplace/latest/userguide/pricing.html)
- [Associating licenses with AMI products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-license-manager-integration.html)
- [Subscribing to an AMI contract product](https://docs.aws.amazon.com/marketplace/latest/buyerguide/sub-public-AMI-contract.html)
- [Buying and launching an AMI product](https://docs.aws.amazon.com/marketplace/latest/buyerguide/tutorial-buying-ami.html)
- [AWS Marketplace Seller Tax Grid](https://aws.amazon.com/tax-help/marketplace-sellers/tax-grid/)
