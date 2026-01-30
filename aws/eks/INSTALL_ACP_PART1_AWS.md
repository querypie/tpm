# QueryPie ACP 설치 가이드 - Part 1: AWS 환경 설정

EKS 외부의 AWS 리소스 (ALB Controller, ACM 인증서)를 설정합니다.

> 참고: [QueryPie 공식 EKS 설치 문서](https://docs.querypie.com/ko/installation/installation/installing-on-aws-eks)

## 설치 정보

| 항목 | 값 |
|------|-----|
| 도메인 | jk-acp.tpm.querypie.io |
| 클러스터 | jk-querypie |
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
        │         EKS Cluster           │
        └───────────────────────────────┘
```

## 사전 요구사항

- EKS 클러스터 (Kubernetes 1.24 이상)
- AWS CLI, kubectl, Helm 3.10.0 이상
- eksctl

---

## 1. AWS Load Balancer Controller 설치

### 1.1 OIDC Provider 생성

EKS 클러스터에 IAM OIDC Provider를 연결합니다.

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster jk-querypie \
  --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess \
  --approve
```

### 1.2 IAM Policy 확인 및 업데이트

AWS Load Balancer Controller가 사용할 IAM Policy가 이미 존재하는지 확인합니다.

```bash
# Check if policy already exists
aws iam list-policies --scope Local --profile 142605707876_AWSAdministratorAccess \
  --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy'].Arn" --output text
```

> **Note:** 이 계정에는 `AWSLoadBalancerControllerIAMPolicy`가 이미 생성되어 있습니다.
> ARN: `arn:aws:iam::142605707876:policy/AWSLoadBalancerControllerIAMPolicy`

<details>
<summary>Policy가 없는 경우 (클릭하여 펼치기)</summary>

```bash
# Download latest policy document
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json

# Create IAM Policy
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json \
  --profile 142605707876_AWSAdministratorAccess
```

</details>

#### IAM Policy 업데이트 (최신 버전 권한 추가)

AWS Load Balancer Controller v2.11+ 버전에서는 `elasticloadbalancing:DescribeListenerAttributes` 권한이 필요합니다. 기존 Policy에 이 권한이 없으면 추가해야 합니다.

```bash
# Download latest policy document
curl -o iam_policy_latest.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json

# Create new policy version
aws iam create-policy-version \
  --policy-arn arn:aws:iam::142605707876:policy/AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy_latest.json \
  --set-as-default \
  --profile 142605707876_AWSAdministratorAccess
```

> **Important:** ALB 생성 시 `DescribeListenerAttributes` 권한 오류가 발생하면 이 단계를 수행하세요.

### 1.3 Service Account 생성

IAM Role과 연결된 Kubernetes Service Account를 생성합니다.

```bash
eksctl create iamserviceaccount \
  --cluster jk-querypie \
  --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::142605707876:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve
```

### 1.4 Helm으로 Controller 설치

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=jk-querypie \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-northeast-2 \
  --set vpcId=$(aws eks describe-cluster --name jk-querypie --region ap-northeast-2 --profile 142605707876_AWSAdministratorAccess --query "cluster.resourcesVpcConfig.vpcId" --output text)
```

### 1.5 설치 확인

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

---

## 2. ACM 인증서 생성

### 2.1 인증서 요청

```bash
aws acm request-certificate \
  --domain-name jk-acp.tpm.querypie.io \
  --validation-method DNS \
  --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess
```

### 2.2 DNS 검증

```bash
# Get certificate ARN
CERT_ARN=$(aws acm list-certificates --region ap-northeast-2 --profile 142605707876_AWSAdministratorAccess \
  --query "CertificateSummaryList[?DomainName=='jk-acp.tpm.querypie.io'].CertificateArn" --output text)

echo "Certificate ARN: $CERT_ARN"

# Get DNS validation info
aws acm describe-certificate --certificate-arn $CERT_ARN --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess \
  --query "Certificate.DomainValidationOptions"
```

Route53에서 해당 CNAME 레코드를 추가하면 자동으로 검증됩니다.

### 2.3 검증 완료 확인

```bash
aws acm describe-certificate --certificate-arn $CERT_ARN --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess \
  --query "Certificate.Status"
```

`ISSUED` 상태가 되면 인증서 사용 가능합니다.

---

## 다음 단계

AWS 환경 설정이 완료되면 [Part 2: EKS Helm 기반 배포](INSTALL_ACP_PART2_HELM.md)를 진행합니다.

---

## 정리 (삭제)

```bash
# Delete AWS Load Balancer Controller
helm uninstall aws-load-balancer-controller -n kube-system

# Delete Service Account
eksctl delete iamserviceaccount \
  --cluster jk-querypie \
  --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess \
  --namespace kube-system \
  --name aws-load-balancer-controller

# Delete ACM certificate (optional)
aws acm delete-certificate --certificate-arn $CERT_ARN \
  --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess
```

---

## 트러블슈팅

### ALB Controller Pod가 시작되지 않는 경우

```bash
# Check Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check Service Account
kubectl get sa -n kube-system aws-load-balancer-controller -o yaml
```

### 인증서 검증이 완료되지 않는 경우

- Route53에 DNS 검증 레코드가 올바르게 추가되었는지 확인
- 도메인의 Hosted Zone이 정확한지 확인

---

## 참고 링크

- [AWS Load Balancer Controller 문서](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [ACM 인증서 요청](https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html)
- [EKS Ingress 가이드](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)
