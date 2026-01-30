# QueryPie ACP 설치 가이드 - Part 2: EKS Helm 기반 배포

Kubernetes 리소스와 QueryPie 애플리케이션을 배포합니다.

> 참고: [QueryPie 공식 EKS 설치 문서](https://docs.querypie.com/ko/installation/installation/installing-on-aws-eks)

## 사전 요구사항

- [Part 1: AWS 환경 설정](INSTALL_ACP_PART1_AWS.md) 완료
- EKS 클러스터 (Kubernetes 1.24 이상)
- 노드: m7i.xlarge (4 vCPU, 16GB RAM) 이상, 최소 2개
- kubectl, Helm 3.10.0 이상

## 설치 정보

| 항목 | 값 |
|------|-----|
| 도메인 | jk-acp.tpm.querypie.io |
| 클러스터 | jk-querypie |
| 네임스페이스 | jk-querypie |
| Container Registry | Docker Hub |
| App 버전 | 11.5.1 |

## Architecture

```
        ┌───────────────────────────────────────────┐
        │              AWS Cloud                    │
        │  ┌─────────────────────────────────────┐  │
        │  │         ALB (HTTPS:443)             │  │
        │  │              │                      │  │
        │  │              ▼                      │  │
        │  │      Kubernetes Ingress             │  │
        │  │              │                      │  │
        │  │              ▼                      │  │
        │  │       QueryPie Service              │  │
        │  │              │                      │  │
        │  │              ▼                      │  │
        │  │     QueryPie StatefulSet            │  │
        │  │              │                      │  │
        │  │       ┌──────┴──────┐               │  │
        │  │       ▼             ▼               │  │
        │  │    MySQL         Redis              │  │
        │  │   (Demo)        (Demo)              │  │
        │  └─────────────────────────────────────┘  │
        └───────────────────────────────────────────┘
```

> **Note:** Demo 모드는 MySQL과 Redis를 자동으로 배포합니다. 프로덕션 환경에서는 외부 관리형 DB/Redis를 사용하세요.

---

## 1. Namespace 생성

```bash
kubectl create namespace jk-querypie
```

---

## 2. QueryPie Secret 생성

QueryPie 설정을 위한 Secret을 생성합니다.

### 2.1 Secret 환경 변수 파일 작성

`querypie.env` 파일을 생성합니다:

```bash
# querypie.env
# Agent authentication secret (min 32 characters)
AGENT_SECRET=01234567890123456789012345678912

# Key Encryption Key (min 32 characters)
KEK=01234567890123456789012345678912

# Main Database (Demo mode: uses internal MySQL)
DB_HOST=mysql
DB_PORT=3306
DB_USERNAME=querypie
DB_PASSWORD=querypie
DB_CATALOG=querypie

# Log Database
LOG_DB_HOST=mysql
LOG_DB_PORT=3306
LOG_DB_USERNAME=querypie
LOG_DB_PASSWORD=querypie
LOG_DB_CATALOG=querypie_log

# Engine/Snapshot Database
ENG_DB_HOST=mysql
ENG_DB_PORT=3306
ENG_DB_USERNAME=querypie
ENG_DB_PASSWORD=querypie
ENG_DB_CATALOG=querypie_snapshot

# Storage Database (10.2.2+)
STORAGE_DB_HOST=mysql
STORAGE_DB_PORT=3306
STORAGE_DB_CATALOG=querypie
STORAGE_DB_USER=querypie
STORAGE_DB_PASSWORD=querypie

# Redis Configuration
REDIS_CONNECTION_MODE=STANDALONE
REDIS_NODES=redis:6379
REDIS_DB=0
REDIS_PASSWORD=querypie
```

### 2.2 Secret 생성

```bash
kubectl create secret generic querypie-secret \
  -n jk-querypie \
  --from-env-file=querypie.env
```

---

## 3. Helm Repository 추가

```bash
helm repo add querypie https://chequer-io.github.io/querypie-deployment/helm-chart
helm repo update
```

---

## 4. Helm Values 파일 작성

`querypie-values.yaml` 파일을 생성합니다:

```yaml
# querypie-values.yaml

# App version
appVersion: &version 11.5.1

global:
  image:
    # Docker Hub registry
    registry: docker.io
    tag: *version
    pullPolicy: IfNotPresent

# QueryPie main application
querypie:
  replicas: 1
  image:
    repository: querypie/querypie
  ingress:
    enabled: true
    ingressClassName: alb
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/certificate-arn: "${CERT_ARN}"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/healthcheck-path: /api/health
    host: jk-acp.tpm.querypie.io
  proxyService:
    enabled: true
    type: LoadBalancer
    externalTrafficPolicy: "Local"
  # Resource configuration
  # Note: m7i.xlarge (16GB RAM) has ~15Gi allocatable memory.
  # Use 8Gi for PoC/Demo, 16Gi requires larger nodes (m7i.2xlarge+)
  resources:
    requests:
      cpu: "2000m"
      memory: 8Gi
    limits:
      cpu: "2000m"
      memory: 8Gi
  # (Optional) Persistent storage for application logs
  # Default: emptyDir (logs are lost when pod restarts)
  # Uncomment below to enable persistent log storage per pod
  # externalStorage:
  #   type: persistentVolumeClaim
  #   persistentVolumeClaim:
  #     spec:
  #       storageClassName: "gp2"
  #       resources:
  #         requests:
  #           storage: 100Gi
  #       accessModes:
  #         - ReadWriteOnce

# QueryPie tools (for migration)
tools:
  enabled: true
  image:
    repository: querypie/querypie-tools

# Configuration
config:
  externalURL: "https://jk-acp.tpm.querypie.io"
  secretName: "querypie-secret"

# Demo mode: Auto-deploy MySQL and Redis
demo:
  enabled: true
  mysql:
    image: mysql:8.0
    rootPassword: "querypie"
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 1000m
        memory: 2Gi
    volumeClaimTemplate:
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 50Gi
  redis:
    image: redis:7.4
    password: "querypie"
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

> **Note:** Docker Hub를 사용하므로 별도의 imagePullSecrets가 필요하지 않습니다.

---

## 5. Helm Chart 설치

### 5.1 ACM 인증서 ARN 확인

```bash
export CERT_ARN=$(aws acm list-certificates --region ap-northeast-2 \
  --profile 142605707876_AWSAdministratorAccess \
  --query "CertificateSummaryList[?DomainName=='jk-acp.tpm.querypie.io'].CertificateArn" \
  --output text)

echo "Certificate ARN: $CERT_ARN"
```

### 5.2 Helm 설치 실행

```bash
# Install with CERT_ARN substitution
envsubst < querypie-values.yaml | helm upgrade --install querypie querypie/querypie \
  -n jk-querypie \
  -f -
```

### 5.3 설치 확인

```bash
# Check all pods
kubectl get pods -n jk-querypie

# Check services
kubectl get svc -n jk-querypie

# Check ingress
kubectl get ingress -n jk-querypie
```

예상 출력:
```
NAME                      READY   STATUS    RESTARTS   AGE
mysql-0                   1/1     Running   0          5m
redis-xxxxxxxxxx-xxxxx    1/1     Running   0          5m
querypie-0                1/1     Running   0          5m
querypie-tools-xxxxxxx    1/1     Running   0          5m
```

---

## 6. 데이터베이스 마이그레이션

QueryPie Pod가 준비되면 데이터베이스 마이그레이션을 실행합니다.

> **Important:** 이 단계를 건너뛰면 `Table 'querypie.system_settings' doesn't exist` 오류가 발생합니다.

```bash
# Wait for MySQL to be ready
kubectl wait --for=condition=ready pod/querypie-querypie-mysql-0 -n jk-querypie --timeout=300s

# Run database migration
kubectl exec -it deployment/querypie-querypie-tools -n jk-querypie -- /app/script/migrate.sh runall
```

### 6.1 마이그레이션 후 Pod 재시작

마이그레이션이 완료되면 QueryPie Pod를 재시작하여 변경사항을 적용합니다.

```bash
kubectl delete pod querypie-querypie-0 -n jk-querypie
```

> Pod는 StatefulSet에 의해 자동으로 재생성됩니다.

---

## 7. Route53 DNS 설정

### 7.1 ALB DNS 이름 확인

```bash
# Wait for ALB to be provisioned (may take 2-3 minutes)
kubectl get ingress -n jk-querypie -w

# Get ALB DNS name
ALB_DNS=$(kubectl get ingress -n jk-querypie -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "ALB DNS: $ALB_DNS"
```

### 7.2 Route53 레코드 생성

```bash
# Get Hosted Zone ID (tpm.querypie.io)
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --profile 142605707876_AWSAdministratorAccess \
  --query "HostedZones[?Name=='tpm.querypie.io.'].Id" --output text | cut -d'/' -f3)

# ALB Hosted Zone ID (ap-northeast-2)
ALB_ZONE_ID="ZWKZPGTI48KDX"

# Create Route53 A record (Alias)
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --profile 142605707876_AWSAdministratorAccess \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "jk-acp.tpm.querypie.io",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "'$ALB_ZONE_ID'",
          "DNSName": "'$ALB_DNS'",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'
```

---

## 8. 접속 확인

### 8.1 DNS 전파 확인

```bash
dig jk-acp.tpm.querypie.io
```

### 8.2 HTTPS 접속 테스트

```bash
curl -I https://jk-acp.tpm.querypie.io
```

### 8.3 브라우저 접속

https://jk-acp.tpm.querypie.io 로 접속하여 QueryPie ACP 로그인 화면이 표시되는지 확인합니다.

---

## 정리 (삭제)

```bash
# Delete QueryPie (includes demo MySQL/Redis)
helm uninstall querypie -n jk-querypie

# Delete secrets
kubectl delete secret querypie-secret -n jk-querypie

# Delete namespace
kubectl delete namespace jk-querypie

# Delete Route53 record (optional)
# Manual deletion via AWS Console recommended
```

---

## 트러블슈팅

### ALB가 생성되지 않는 경우

```bash
# Check Ingress events
kubectl describe ingress -n jk-querypie

# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Pod가 시작되지 않는 경우

```bash
# Check pod status and events
kubectl describe pod -n jk-querypie -l app.kubernetes.io/name=querypie

# Check logs
kubectl logs -n jk-querypie -l app.kubernetes.io/name=querypie
```

### Table doesn't exist 오류

데이터베이스 마이그레이션을 실행하지 않은 경우 발생합니다:

```bash
kubectl exec -it deployment/querypie-querypie-tools -n jk-querypie -- /app/script/migrate.sh runall

# 마이그레이션 후 QueryPie Pod 재시작
kubectl delete pod querypie-querypie-0 -n jk-querypie
```

### Demo MySQL 연결 확인

```bash
# Check MySQL pod
kubectl exec -it querypie-querypie-mysql-0 -n jk-querypie -- mysql -uroot -pquerypie -e "SHOW DATABASES;"
```

### Demo Redis 연결 확인

```bash
# Check Redis connection
kubectl exec -it querypie-querypie-redis-0 -n jk-querypie -- redis-cli -a querypie PING
```

---

## 참고 링크

- [QueryPie 공식 EKS 설치 문서](https://docs.querypie.com/ko/installation/installation/installing-on-aws-eks)
- [Helm Chart GitHub](https://github.com/chequer-io/querypie-deployment)
