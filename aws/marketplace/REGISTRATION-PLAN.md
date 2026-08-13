# QueryPie ACP AWS Marketplace 최종 등록 계획

## 범위

이 계획은 QueryPie ACP Community Edition과 QueryPie ACP Standard Edition을 각각 Public Single AMI 상품으로 등록하는 절차를 정의합니다.
Seller 등록과 Enterprise Edition은 이 계획의 범위에 포함하지 않습니다.

## 최종 상품 구조

Community와 Standard는 가격, 권리, 지원 조건이 다르므로 별도 AWS Marketplace 상품으로 등록합니다.
각 상품은 자체 Product ID, Product code, SKU와 Public Offer를 가집니다.
상품 SKU와 기본 사용자 수는 [QueryPie ACP 가격 정책 - 2026 최신](https://querypie.atlassian.net/wiki/spaces/QPBusiness/pages/2311061525/QueryPie+ACP+-+2026)을 기준으로 합니다.

| 상품 | Product SKU | 가격 모델 | 사용자 권리 |
|------|-------------|-----------|-------------|
| QueryPie ACP Community Edition | `QP1201E-CDS-AWS` | Free | 최대 5 active users |
| QueryPie ACP Standard Edition | `QP1201E-SDS-AWS` | AMI with contract pricing | 구매한 10/15/20 users tier |

## Standard 가격 dimension

Standard는 Product SKU 하나를 유지하고 사용자 수를 tiered Contract pricing dimension으로 구분합니다.
구매자는 다음 세 dimension 중 하나만 선택합니다.

| Dimension API name | 구매자 표시명 | 12개월 선불 가격 | 적용 권리 |
|--------------------|---------------|-----------------|-----------|
| `Standard10Users` | `Standard 10 Users` | `6000.000 USD` | 최대 10 active users |
| `Standard15Users` | `Standard 15 Users` | `9000.000 USD` | 최대 15 active users |
| `Standard20Users` | `Standard 20 Users` | `12000.000 USD` | 최대 20 active users |

가격 기준은 사용자 1명당 연간 `USD 600`입니다.
VAT, GST, 판매세와 AWS 인프라 요금은 소프트웨어 가격과 별도입니다.
간접세는 별도 dimension으로 등록하지 않고 AWS Marketplace의 국가별 세금 처리에 따릅니다.

다음 코드는 AWS Marketplace SKU로 등록하지 않습니다.

- `QP1201E-SDS-AWS10`
- `QP1201E-SDS-AWS15`
- `QP1201E-SDS-AWS20`
- `QP1201E-SAS-AWS`

필요한 경우에만 사내 ERP에서 추가 사용자를 분해하는 내부 관리 코드로 사용합니다.

## 버전 등록

각 상품에 동일한 두 소프트웨어 버전을 등록합니다.

| 등록 순서 | Version title | 상태 기준 |
|-----------|---------------|-----------|
| 1 | `11.5.7` | 판매자 계정 `us-east-1` AMI와 스캔 결과 확인 |
| 2 | `11.6.4` | 판매자 계정 `us-east-1` AMI를 준비한 뒤 스캔 |

버전은 에디션이나 사용자 tier를 구분하는 용도로 사용하지 않습니다.
각 Version title은 상품 안에서 고유해야 하며 해당 버전의 AMI와 변경할 수 없게 연결됩니다.
`11.6.4` AMI가 준비되지 않았다면 해당 버전은 생성하거나 Public 제출하지 않습니다.

## 라이선스 적용

Community는 추가 신청 폼, 이메일 입력 또는 별도 라이선스 파일 없이 최대 5명의 권리를 자동 활성화해야 합니다.
Standard는 AWS License Manager의 tiered license model에 따라 가능한 세 dimension을 `CheckoutLicense`에 전달하고, 응답에 반환된 구매 dimension 하나를 확인합니다.

| Entitlement | 활성 사용자 상한 |
|-------------|------------------|
| `Standard10Users` | 10 |
| `Standard15Users` | 15 |
| `Standard20Users` | 20 |

Standard entitlement가 없거나, 둘 이상이거나, 알 수 없는 이름이거나, 만료되면 10 users를 기본으로 부여하지 않습니다.
이 경우 Standard Edition 활성화를 차단하고 구매 또는 갱신 안내를 제공합니다.

Contract 라이선스는 특정 EC2 인스턴스에 고정되지 않습니다.
여러 인스턴스를 허용할 경우 사용자 상한을 설치별로 적용할지 구매 AWS 계정 전체로 적용할지 출시 전에 확정해야 합니다.

## AMI 준비

각 제출 AMI는 다음 조건을 충족해야 합니다.

- 판매자 계정의 `us-east-1`에 존재합니다.
- EBS snapshot과 파일시스템은 암호화되지 않습니다.
- HVM, EBS-backed, x86-64 또는 64-bit ARM 아키텍처를 사용합니다.
- AMI Name과 Description에 정확한 상품명, 에디션, 버전, OS를 기록합니다.
- 고정 비밀번호, 자격 증명, SSH authorized key를 포함하지 않습니다.
- `Test Add Version` 스캔을 문제없이 통과합니다.

에디션별 권리와 Product code를 명확히 적용할 수 있도록 Community와 Standard 제출 AMI를 별도 자산으로 관리합니다.

## 등록 순서

1. Community와 Standard의 상품 메타데이터, SKU, EULA, 지원 정보와 국가 범위를 입력합니다.
2. 각 상품의 첫 버전과 AMI deployment 정보를 입력하여 Limited 상품을 생성합니다.
3. Standard에 tiered Contract pricing과 12개월 가격을 입력합니다.
4. 내부 구매 계정을 allowlist에 추가합니다.
5. 각 AMI에 대해 `Test Add Version`과 보안 스캔을 완료합니다.
6. Community 무료 활성화와 Standard의 세 tier 구매를 각각 검증합니다.
7. 구매 후 버전과 리전을 선택하고 EC2 인스턴스를 생성합니다.
8. QueryPie가 구매한 사용자 권리를 적용하는지 확인합니다.
9. 두 번째 소프트웨어 버전을 추가하고 동일한 실행 검증을 반복합니다.
10. 상품별로 Public 전환 요청을 제출합니다.

## Public 제출 전 완료 조건

- Community가 개인정보나 외부 라이선스 신청 없이 활성화됩니다.
- Standard의 10/15/20 users tier가 하나의 Product SKU 아래에 표시됩니다.
- 세 tier가 각각 `6000`, `9000`, `12000 USD`로 선불 청구됩니다.
- License Manager entitlement와 QueryPie 사용자 상한이 일치합니다.
- entitlement가 없거나 만료된 Standard 인스턴스가 활성화되지 않습니다.
- `11.5.7`과 `11.6.4`의 AMI 소유권, 이름, Description과 스캔 결과를 확인했습니다.
- 구매자가 Marketplace 구독 후 EC2 VM을 정상 생성하고 최초 관리자 설정을 완료할 수 있습니다.
- 환불 정책, 관련 세금, AWS 인프라 비용과 지원 범위가 상품 설명에 표시됩니다.

## 남은 결정

- Standard 다중 EC2 인스턴스의 사용자 상한을 설치별 또는 구매 계정 전체 중 하나로 확정합니다.
- Public 구매 허용 국가와 환불 조건을 확정합니다.
- `11.6.4` 제출 AMI의 실제 준비 상태를 확인합니다.

위 항목이 해결되기 전에는 Public 전환 요청을 제출하지 않습니다.
