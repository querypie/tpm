# EKS Cluster 구성 가이드

QueryPie ACP 제품 설치 및 검증을 위한 EKS Cluster 구성 절차입니다.

## 현재 구성된 클러스터 정보

| 항목 | 값 |
|------|-----|
| 클러스터 이름 | jk-querypie |
| AWS Account | 142605707876 (QPE) |
| 리전 | ap-northeast-2 (서울) |
| Kubernetes 버전 | 1.29 |
| 노드 그룹 | standard-workers-m7i |
| 노드 타입 | m7i.xlarge (4 vCPU, 16GB RAM) |
| 노드 수 | 2 (min: 1, max: 3) |
| API Endpoint | https://8BEED4DE1ADF092D73E5546DD845F3AF.gr7.ap-northeast-2.eks.amazonaws.com |
| 생성일 | 2026-01-30 |

**노드 목록:**
- ip-192-168-61-24.ap-northeast-2.compute.internal
- ip-192-168-64-184.ap-northeast-2.compute.internal

## 사전 요구사항

### 필수 도구 설치

```bash
# AWS CLI v2
brew install awscli

# eksctl
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# kubectl
brew install kubectl

# helm (QueryPie 설치용)
brew install helm
```

### AWS Credential 설정

QPE AWS Account (142605707876)에 접근하기 위한 credential을 설정합니다.

**사용 프로파일:** `142605707876_AWSAdministratorAccess`

AWS SSO를 통해 credential을 발급받아 `~/.aws/credentials` 파일에 설정합니다:

```ini
[142605707876_AWSAdministratorAccess]
aws_access_key_id=ASIA...
aws_secret_access_key=...
aws_session_token=...
```

> SSO 세션 토큰은 일정 시간 후 만료되므로, 만료 시 AWS Console에서 새로 발급받아야 합니다.

credential 설정 확인:
```bash
aws sts get-caller-identity --profile 142605707876_AWSAdministratorAccess
```

정상 출력 예시:
```json
{
    "UserId": "AROASCM7WNJSIMCROY4JF:jk@chequer.io",
    "Account": "142605707876",
    "Arn": "arn:aws:sts::142605707876:assumed-role/AWSReservedSSO_AWSAdministratorAccess_.../jk@chequer.io"
}
```

## EKS Cluster 생성

### 1. Cluster 생성 (eksctl 사용)

기본 설정으로 EKS Cluster를 생성합니다. `eksctl`은 VPC, Subnet, Security Group, IAM Role 등을 자동으로 구성합니다.

```bash
eksctl create cluster \
  --name jk-querypie \
  --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess \
  --version 1.29 \
  --nodegroup-name standard-workers-m7i \
  --node-type m7i.xlarge \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed
```

**파라미터 설명:**
- `--name`: 클러스터 이름
- `--region`: AWS 리전 (서울)
- `--version`: Kubernetes 버전
- `--node-type`: EC2 인스턴스 타입 (m7i.xlarge: 4 vCPU, 16GB RAM, Intel 7세대)
- `--nodes`: 초기 노드 수
- `--managed`: AWS 관리형 노드 그룹 사용

> 클러스터 생성에는 약 15-20분이 소요됩니다.

### 2. Cluster 연결 확인

```bash
# kubeconfig 업데이트
aws eks update-kubeconfig --name jk-querypie --region ap-northeast-2 --profile 142605707876_AWSAdministratorAccess

# 클러스터 연결 확인
kubectl get nodes
kubectl cluster-info
```

### 3. 필수 애드온 확인

EKS 기본 애드온이 정상 설치되었는지 확인합니다:

```bash
kubectl get pods -n kube-system
```

## EBS CSI Driver 설치 (필수)

QueryPie는 PersistentVolume을 사용하므로 EBS CSI Driver가 필요합니다.

> **Important:** OIDC Provider와 IAM Role을 먼저 생성해야 EBS CSI Driver가 정상 작동합니다.

### 4.1 OIDC Provider 연결

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster jk-querypie \
  --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess \
  --approve
```

### 4.2 EBS CSI Driver IAM Role 생성

```bash
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster jk-querypie \
  --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess \
  --role-name AmazonEKS_EBS_CSI_DriverRole_jk-querypie \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve
```

### 4.3 EBS CSI Driver 애드온 설치

```bash
eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster jk-querypie \
  --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess \
  --service-account-role-arn arn:aws:iam::142605707876:role/AmazonEKS_EBS_CSI_DriverRole_jk-querypie \
  --force
```

### 4.4 설치 확인

```bash
kubectl get pods -n kube-system | grep ebs
```

예상 출력:
```
ebs-csi-controller-xxxxx   6/6     Running   0          1m
ebs-csi-node-xxxxx         3/3     Running   0          1m
```

## 정리 (Cluster 삭제)

테스트 완료 후 리소스를 삭제합니다:

```bash
eksctl delete cluster \
  --name jk-querypie \
  --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess
```

> 삭제에는 약 10-15분이 소요됩니다.

## 참고사항

- 클러스터 생성 시 자동으로 생성되는 리소스:
  - VPC 및 Subnet (Public/Private)
  - Internet Gateway, NAT Gateway
  - Security Groups
  - IAM Roles (Cluster, Node Group)

- 비용 관련:
  - EKS Control Plane: $0.10/시간
  - EC2 인스턴스 (m7i.xlarge x 2): 약 $0.202/시간 x 2
  - NAT Gateway: $0.045/시간 + 데이터 전송 비용

## 트러블슈팅

### eksctl 명령 실패 시
```bash
# CloudFormation 스택 상태 확인
aws cloudformation describe-stacks --profile 142605707876_AWSAdministratorAccess --region ap-northeast-2
```

### kubectl 연결 실패 시
```bash
# kubeconfig 재설정
aws eks update-kubeconfig --name jk-querypie --region ap-northeast-2 --profile 142605707876_AWSAdministratorAccess
```
