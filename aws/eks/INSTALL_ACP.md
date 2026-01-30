# QueryPie ACP 설치 가이드 (EKS + ALB)

EKS 클러스터에 ALB Ingress를 통해 QueryPie ACP를 설치하는 가이드입니다.

> 참고: [QueryPie 공식 EKS 설치 문서](https://docs.querypie.com/ko/installation/installation/installing-on-aws-eks)

## 설치 정보

| 항목 | 값 |
|------|-----|
| 도메인 | jk-acp.tpm.querypie.io |
| 클러스터 | jk-querypie |
| 네임스페이스 | jk-querypie |
| 리전 | ap-northeast-2 |
| 연결 방식 | ALB + Ingress Controller |
| 인증서 | ACM (AWS Certificate Manager) |

## Architecture

```
                    Internet
                        │
                        ▼
        ┌───────────────────────────────┐
        │           Route53             │
        │   jk-acp.tpm.querypie.io      │
        └───────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │    ALB (Application LB)       │
        │  - HTTPS termination (ACM)    │
        │  - Health check               │
        └───────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │  AWS Load Balancer Controller │
        │      (Ingress Controller)     │
        └───────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │      Kubernetes Ingress       │
        │              │                │
        │              ▼                │
        │       QueryPie Service        │
        │              │                │
        │              ▼                │
        │        QueryPie Pods          │
        │              │                │
        │       ┌──────┴──────┐         │
        │       ▼             ▼         │
        │    MySQL         Redis        │
        └───────────────────────────────┘
```

## 설치 가이드

### [Part 1: AWS 환경 설정](INSTALL_ACP_PART1_AWS.md)

EKS 외부의 AWS 리소스를 설정합니다.

- AWS Load Balancer Controller 설치
- ACM 인증서 생성 및 DNS 검증

### [Part 2: EKS Helm 기반 배포](INSTALL_ACP_PART2_HELM.md)

Kubernetes 리소스와 QueryPie 애플리케이션을 배포합니다.

- Namespace, MySQL, Redis 설치
- QueryPie Helm 배포
- 데이터베이스 마이그레이션
- Route53 DNS 설정
- 접속 확인

## 사전 요구사항

- EKS 클러스터 (Kubernetes 1.24 이상) - [SETUP_CLUSTER.md](SETUP_CLUSTER.md) 참조
- 노드: m7i.xlarge (4 vCPU, 16GB RAM) 이상, 최소 2개
- AWS CLI, kubectl, Helm 3.10.0 이상, eksctl

## 참고 링크

- [QueryPie 공식 EKS 설치 문서](https://docs.querypie.com/ko/installation/installation/installing-on-aws-eks)
- [AWS Load Balancer Controller 문서](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EKS Ingress 가이드](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)
