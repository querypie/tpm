# Long description

## English - AWS source

QueryPie ACP Standard Edition is a self-managed access control platform for production teams starting at 10 active users.
It unifies access governance for databases, servers, Kubernetes clusters, and MCP tools in a single administrative interface.

Users can execute database queries and inspect results in the Web SQL Editor, run server commands in the Web Terminal, and use the Kubernetes Web Client (beta) to browse cluster resources, stream Pod logs, and open Pod shells from a browser.
Each client operates under the applicable QueryPie access controls and complements proxy, Agent, and local-tool connection methods.

Administrators can register resources, apply fine-grained permissions, route access and execution requests through approval workflows, and review privileged activity through audit logs and session records.
Proxy-based controls help teams grant access based on policy while reducing reliance on standing credentials.

The product is delivered as a preconfigured AMI on Amazon Linux 2023 and runs containerized application, database, and cache components in the buyer's AWS account.
It is intended for production teams that need licensed capacity starting at 10 active users while retaining a customer-operated deployment model.
Customers purchase a 12-month AWS Marketplace contract for one of the available user tiers.
The purchased entitlement is fulfilled as a signed `.crt` file that customers upload to the web console.
The QueryPie ACP container validates the license locally using PKI and does not require an ongoing connection to an external license service after activation.
AWS Marketplace software charges and AWS infrastructure charges are billed separately.

## 한국어 리뷰용 번역

QueryPie ACP Standard Edition은 10명 이상의 활성 사용자로 시작하는 운영 팀을 위한 자체 운영형 접근 제어 플랫폼입니다.
하나의 관리 인터페이스에서 데이터베이스, 서버, Kubernetes 클러스터, MCP 도구의 접근 거버넌스를 통합합니다.

사용자는 브라우저의 Web SQL Editor에서 데이터베이스 쿼리를 실행하고 결과를 확인하며, Web Terminal에서 서버 명령을 실행하고, Kubernetes Web Client(베타)에서 클러스터 리소스를 탐색하고 Pod 로그를 스트리밍하며 Pod 셸을 열 수 있습니다.
각 클라이언트에는 해당 QueryPie 접근 제어가 적용되며 프록시, Agent, 로컬 도구 연결 방식을 보완합니다.

관리자는 리소스를 등록하고 세분화된 권한을 적용하며, 접근과 실행 요청을 승인 워크플로로 처리하고, 감사 로그와 세션 기록으로 권한 사용 활동을 검토할 수 있습니다.
프록시 기반 제어는 상시 자격 증명에 대한 의존을 줄이면서 정책에 따라 접근 권한을 부여하도록 지원합니다.

이 상품은 Amazon Linux 2023 기반의 사전 구성된 AMI로 제공되며, 구매자의 AWS 계정에서 컨테이너화된 애플리케이션, 데이터베이스, 캐시 구성 요소를 실행합니다.
고객이 직접 운영하는 배포 모델을 유지하면서 10명 이상의 활성 사용자에 대한 라이선스 용량이 필요한 운영 팀에 적합합니다.
구매자는 제공되는 사용자 tier 중 하나에 대해 12개월 AWS Marketplace 계약을 구매합니다.
구매 권리는 서명된 `.crt` 파일로 발급되며 구매자가 웹 콘솔에 등록합니다.
QueryPie ACP 컨테이너는 활성화 후 지속적인 외부 라이선스 서비스 연결 없이 PKI 방식으로 라이선스를 로컬에서 검증합니다.
AWS Marketplace 소프트웨어 요금과 AWS 인프라 요금은 별도로 청구됩니다.
