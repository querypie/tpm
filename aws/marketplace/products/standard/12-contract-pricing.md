# Contract pricing

## 제출 상태

이 문서는 QueryPie ACP Standard Edition 유료 상품의 준비용 초안입니다.
별도 사업·기술 검토가 승인되기 전에는 이 입력값으로 Partner Central 상품을 생성하거나 제출하지 않습니다.

## 결정 초안

QueryPie ACP Standard Edition은 `AMI with contract pricing`과 tiered entitlement를 사용합니다.
AWS Marketplace Product SKU는 `QP1201E-SDS-AWS` 하나만 사용합니다.
구매자는 12개월 계약을 생성할 때 10, 15, 20 users 중 하나를 선택합니다.

## AWS 입력값 초안

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

사용자 수별 파생 SKU와 `QP1201E-SAS-AWS`는 AWS Marketplace에 등록하지 않습니다.
VAT, GST, 판매세 같은 간접세를 별도 계약 차원으로 추가하지 않습니다.
가격, 세금, 환불 조건은 실제 등록 검토에서 다시 승인합니다.

## 애플리케이션 권리 적용 초안

QueryPie ACP 런타임은 서명된 `.crt` 라이선스를 컨테이너 내부에서 로컬로 검증합니다.
Standard를 유료 Contract 상품으로 등록하려면 AWS Marketplace가 제공한 구매 tier를 확인하고 그 권리에 맞는 `.crt`를 자동 발급하는 연결이 필요합니다.

등록 검토 전까지 다음 항목을 설계·검증합니다.

- AWS Contract entitlement를 검증하는 주체와 시점
- `Standard10Users`, `Standard15Users`, `Standard20Users`에서 `.crt` 권리로 변환하는 규칙
- entitlement 없음, 중복, 알 수 없는 값, 만료 또는 비활성 상태의 차단 처리
- 계약 갱신과 tier 변경 반영
- 다중 EC2 인스턴스의 사용자 상한 적용 범위
- 최소 권한 IAM 정책과 Limited 통합 테스트

이 연결이 구현·검증되기 전에는 Standard 상품을 생성하거나 제출하지 않습니다.

## 향후 구매 흐름

별도 검토가 승인된 뒤 다음 흐름을 Limited 상품에서 검증합니다.

1. 구매자가 Standard의 10/15/20 users 계약 옵션 중 하나를 선택합니다.
2. AWS Marketplace가 구매 권리를 생성합니다.
3. QueryPie 라이선스 발급 절차가 구매 권리를 확인해 해당 tier의 서명 `.crt`를 자동 발급합니다.
4. 구매자가 `.crt`를 웹 콘솔에 등록합니다.
5. QueryPie ACP가 서명과 권리를 로컬에서 검증하고 활성 사용자 상한을 적용합니다.

## 재검토 게이트

- 가격과 10/15/20 users 상품 구성이 승인되었습니다.
- AWS Contract 권리와 `.crt` 자동 발급 연결이 구현되었습니다.
- entitlement 오류와 만료 시 활성화 차단이 검증되었습니다.
- 다중 인스턴스 권리 범위가 확정되었습니다.
- 제출 AMI, 사용 지침, 국가, 환불과 지원 조건이 준비되었습니다.
- Limited 구매·실행 테스트 계획이 승인되었습니다.

게이트를 모두 충족해도 별도 등록 승인 없이는 Partner Central에 상품을 생성하거나 제출하지 않습니다.

## 공식 근거

- [Contract pricing for AMI products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-contracts.html)
- [Associating licenses with AMI products](https://docs.aws.amazon.com/marketplace/latest/userguide/ami-license-manager-integration.html)
- [Subscribing to an AMI contract product](https://docs.aws.amazon.com/marketplace/latest/buyerguide/sub-public-AMI-contract.html)
- [Product pricing](https://docs.aws.amazon.com/marketplace/latest/userguide/pricing.html)
- [AWS Marketplace Seller Tax Grid](https://aws.amazon.com/tax-help/marketplace-sellers/tax-grid/)
