# AWS Marketplace 번역 운영 방식

## 결론

AWS Marketplace 상품 등록 정보는 영어로 제출합니다.
AWS Marketplace는 영어 원문을 한국어, 일본어, 프랑스어, 스페인어로 기본 자동 번역합니다.
자동 번역 제외를 요청하지 않고 AWS의 기본 동작을 그대로 사용합니다.

저장소에서는 다음 원칙을 적용합니다.

1. 각 상품 파일의 영어 문안을 실제 AWS 제출 원문으로 사용합니다.
2. 모든 영어 설명 문구 바로 아래에 한국어 리뷰용 번역을 둡니다.
3. 한국어 번역은 개발자 리뷰를 위한 자료이며 AWS에 별도 입력하지 않습니다.
4. 일본어, 프랑스어, 스페인어 문안은 저장소에서 별도로 관리하지 않습니다.
5. 실제 등록 대상으로 승인된 상품이 Limited 상태가 되면 영어 원문과 AWS 자동 번역이 정상적으로 노출되는지 확인합니다.

## 실제 노출 방식

AWS Marketplace에서 상품 언어는 배포 AWS 리전이나 구매 국가가 아니라 구매자의 Marketplace 언어 설정에 따라 결정됩니다.
영어 UI에서는 판매자가 제출한 영어 원문이 보입니다.
AWS가 지원하는 현지 언어 UI에서는 영어 원문의 자동 번역이 보입니다.
판매자는 한 화면에 영어와 현지 언어를 동시에 표시하거나 배포 리전별로 설명 언어를 강제하지 않습니다.

| 구매자 UI 언어 | 노출 문구 |
|----------------|-----------|
| 영어 | 판매자가 제출한 영어 원문 |
| 한국어 | AWS가 생성한 한국어 자동 번역 |
| 일본어 | AWS가 생성한 일본어 자동 번역 |
| 프랑스어 | AWS가 생성한 프랑스어 자동 번역 |
| 스페인어 | AWS가 생성한 스페인어 자동 번역 |
| 그 외 지원되지 않는 언어 | 영어 원문 |

## EULA 현지화

상품 정보와 달리 EULA는 AWS가 지원하는 언어로 제출할 수 있습니다.
현지 언어 EULA를 사용할 때는 해당 상품 오퍼를 그 언어가 주 언어인 국가에 geo-targeting해야 합니다.
세 상품에는 영어로 제공되는 [QueryPie EULA](https://www.querypie.com/eula)를 사용하며 별도의 현지 언어 EULA는 관리하지 않습니다.

## 검수 절차

1. Community를 Limited 상태로 전환합니다.
2. 영어 화면에서 제목, 짧은 설명, 긴 설명, Highlights, 지원 정보, 리소스 이름이 제출 원문과 일치하는지 확인합니다.
3. 한국어를 포함한 AWS 기본 자동 번역 화면이 생성되었는지 확인합니다.
4. 제품명, QueryPie ACP, DAC, SAC, KAC, WAC, MCP 같은 고유명사가 읽기 어렵게 번역되지 않았는지 표본 점검합니다.
5. 의미를 크게 훼손하는 번역이 있으면 화면 캡처, Listing ID, 영어 원문을 포함해 AWS에 문의합니다.
6. AMI와 실행 흐름 검증을 마친 뒤 Community만 Public 전환을 요청합니다.
7. Standard는 별도 등록 검토가 승인된 이후 같은 절차를 수행합니다.
8. Enterprise는 Limited 상태에서 allowlist된 Private Offer 구매자 화면만 검수하고 Public 전환하지 않습니다.

## 공식 근거

- [Translation and languages](https://docs.aws.amazon.com/marketplace/latest/userguide/translation.html)
- [Regions and countries for your AWS Marketplace product](https://docs.aws.amazon.com/marketplace/latest/userguide/regions-and-countries.html)
