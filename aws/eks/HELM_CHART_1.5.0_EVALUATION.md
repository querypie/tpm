# QueryPie Helm Chart 1.5.0 평가 결과

QueryPie ACP Helm Chart 버전 1.5.0에 대한 검증 테스트 결과입니다.

## 테스트 환경

| 항목 | 값 |
|------|-----|
| 테스트 일자 | 2026-01-30 |
| Helm Chart 버전 | 1.5.0 |
| App 버전 | 11.5.1 |
| EKS 클러스터 | jk-querypie |
| Kubernetes 버전 | 1.29 |
| 노드 타입 | m7i.xlarge (4 vCPU, 16GB RAM) |
| 노드 수 | 2 |
| 배포 모드 | Demo (내장 MySQL/Redis) |
| Container Registry | Docker Hub (docker.io) |

## 배포 구성

```
┌─────────────────────────────────────────────────────────────┐
│                      EKS Cluster                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                 Namespace: jk-querypie                │  │
│  │                                                       │  │
│  │  ┌─────────────────┐  ┌─────────────┐  ┌───────────┐  │  │
│  │  │   QueryPie      │  │   MySQL     │  │   Redis   │  │  │
│  │  │  StatefulSet    │  │ StatefulSet │  │ StatefulSet│  │  │
│  │  │   (1 replica)   │  │ (1 replica) │  │(1 replica)│  │  │
│  │  │                 │  │             │  │           │  │  │
│  │  │  Memory: 8Gi    │  │ Memory: 2Gi │  │ Mem: 512Mi│  │  │
│  │  │  CPU: 2000m     │  │ CPU: 1000m  │  │ CPU: 500m │  │  │
│  │  └────────┬────────┘  └──────┬──────┘  └─────┬─────┘  │  │
│  │           │                  │               │        │  │
│  │           │     ┌────────────┴───────────────┘        │  │
│  │           │     │                                     │  │
│  │           ▼     ▼                                     │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │              PersistentVolumes (EBS)            │  │  │
│  │  │   MySQL: 50Gi          Redis: (emptyDir)       │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                           │                                 │
│              ┌────────────┴────────────┐                    │
│              ▼                         ▼                    │
│     ┌─────────────────┐      ┌─────────────────┐            │
│     │   ALB Ingress   │      │  NLB (Proxy)    │            │
│     │   HTTPS:443     │      │  9000,6443,     │            │
│     │                 │      │  9022,7447      │            │
│     └─────────────────┘      └─────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## 테스트 결과 요약

| 테스트 항목 | 결과 | 비고 |
|------------|------|------|
| Helm 설치 | ✅ 성공 | envsubst로 인증서 ARN 주입 |
| Pod 배포 | ✅ 성공 | 모든 Pod Running 상태 |
| MySQL 연결 | ✅ 성공 | Demo 모드 내장 MySQL |
| Redis 연결 | ✅ 성공 | Demo 모드 내장 Redis |
| DB 마이그레이션 | ✅ 성공 | migrate.sh runall |
| ALB Ingress | ✅ 성공 | HTTPS 정상 응답 |
| NLB Proxy | ✅ 성공 | 4개 포트 정상 |
| Health Check | ✅ 성공 | /api/health 응답 |
| 라이선스 활성화 | ✅ 성공 | UI 통해 활성화 |

**전체 평가: PASSED**

## 발견된 이슈 및 해결 방법

### 1. EBS CSI Driver IAM 권한 오류

**증상:**
```
failed to provision volume: rpc error: AccessDeniedException:
User is not authorized to perform: sts:AssumeRoleWithWebIdentity
```

**원인:** EBS CSI Driver의 Service Account에 연결된 IAM Role에 OIDC Trust Policy가 올바르게 설정되지 않음

**해결:**
```bash
# OIDC Provider 연결
eksctl utils associate-iam-oidc-provider --cluster jk-querypie --approve

# IAM Role 생성 (OIDC Trust 자동 설정)
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster jk-querypie \
  --role-name AmazonEKS_EBS_CSI_DriverRole_jk-querypie \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

# EBS CSI Driver 애드온 설치
eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster jk-querypie \
  --service-account-role-arn arn:aws:iam::142605707876:role/AmazonEKS_EBS_CSI_DriverRole_jk-querypie \
  --force
```

**문서 반영:** SETUP_CLUSTER.md에 추가 완료

---

### 2. ALB Controller DescribeListenerAttributes 권한 오류

**증상:**
```
AccessDenied: User is not authorized to perform:
elasticloadbalancing:DescribeListenerAttributes
```

**원인:** AWS Load Balancer Controller v2.11+ 버전에서 새로 요구하는 권한이 기존 IAM Policy에 누락

**해결:**
```bash
# 최신 Policy 다운로드
curl -o iam_policy_latest.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json

# Policy 버전 업데이트
aws iam create-policy-version \
  --policy-arn arn:aws:iam::142605707876:policy/AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy_latest.json \
  --set-as-default
```

**문서 반영:** INSTALL_ACP_PART1_AWS.md에 추가 완료

---

### 3. Pod Insufficient Memory

**증상:**
```
0/2 nodes are available: 2 Insufficient memory.
```

**원인:** 기본 메모리 설정 16Gi가 m7i.xlarge 노드의 allocatable memory (~15Gi)를 초과

**해결:** Helm values에서 메모리를 8Gi로 조정

```yaml
querypie:
  resources:
    requests:
      memory: 8Gi
    limits:
      memory: 8Gi
```

**문서 반영:** INSTALL_ACP_PART2_HELM.md에 주석으로 설명 추가

---

## 로그 분석 결과

### 정상 동작 로그 (예상된 경고)

| 로그 유형 | 내용 | 평가 |
|----------|------|------|
| SUPERVISOR | 서비스 대기 메시지 | ✅ 정상 (시작 순서) |
| NGINX | `listen ... http2` deprecated | ✅ 정상 (기능 영향 없음) |
| Logback | 파일 로깅 설정 경고 | ✅ 정상 |
| Health Check | 시작 중 Connection refused | ✅ 정상 (초기화 중) |

### 경미한 이슈 (비영향)

| 로그 유형 | 내용 | 평가 |
|----------|------|------|
| Certificate | `/app/certificate/querypie.pfx` 미존재 | ⚠️ 경미 (클라이언트 인증서 미사용 시 무시) |
| Hibernate | H2 dialect fallback | ⚠️ 경미 (기능 영향 없음) |
| Spring | Bean 순환 참조 경고 | ⚠️ 경미 (자동 해결됨) |

### 주의 필요 로그

| 로그 유형 | 내용 | 평가 |
|----------|------|------|
| ENGINE | `renewWindowAlerted failed: WindowSession Not Found` | ⚠️ 주의 (DAC 세션 관리, 기능 영향 낮음) |

**로그 분석 결론:** 치명적인 오류 없음. 모든 핵심 기능 정상 동작.

---

## 리소스 사용량

테스트 시점 Pod 메모리 사용량:

| Pod | 요청/제한 | 실제 사용량 | 사용률 |
|-----|----------|------------|--------|
| querypie-querypie-0 | 8Gi / 8Gi | ~3.7Gi | 46% |
| querypie-querypie-mysql-0 | 1Gi / 2Gi | ~0.8Gi | 40% |
| querypie-querypie-redis-0 | 256Mi / 512Mi | ~10Mi | 2% |

**리소스 평가:** 현재 8Gi 설정은 PoC/Demo 환경에 적합. 프로덕션 환경에서는 워크로드에 따라 조정 필요.

---

## 결론

### Helm Chart 1.5.0 평가

| 항목 | 평가 |
|------|------|
| 설치 용이성 | ✅ 양호 |
| 안정성 | ✅ 양호 |
| Demo 모드 | ✅ 정상 동작 |
| 문서 정합성 | ⚠️ IAM 권한 관련 보완 필요 (문서 업데이트 완료) |

**최종 평가: PASSED**

Helm Chart 1.5.0은 QueryPie ACP 11.5.1 배포에 문제없이 사용 가능합니다.
설치 과정에서 발견된 AWS IAM 권한 이슈는 환경 설정 문서(Part 1, SETUP_CLUSTER)에 반영하여 해결하였습니다.

---

## 참고 자료

- [설치 가이드 Part 1: AWS 환경 설정](INSTALL_ACP_PART1_AWS.md)
- [설치 가이드 Part 2: Helm 배포](INSTALL_ACP_PART2_HELM.md)
- [EKS 클러스터 구성 가이드](SETUP_CLUSTER.md)
- [QueryPie Helm Chart GitHub](https://github.com/chequer-io/querypie-deployment)
