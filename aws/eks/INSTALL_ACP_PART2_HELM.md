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

## Architecture

```
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

---

## 1. Namespace 생성

```bash
kubectl create namespace jk-querypie
```

---

## 2. MySQL 설치

QueryPie 메타데이터 저장용 MySQL을 설치합니다.

### 2.1 PersistentVolumeClaim 생성

```yaml
# mysql-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: jk-querypie
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp2
  resources:
    requests:
      storage: 50Gi
```

```bash
kubectl apply -f mysql-pvc.yaml
```

### 2.2 MySQL Secret 생성

```bash
kubectl create secret generic mysql-secret \
  -n jk-querypie \
  --from-literal=root-password='YourRootPassword123!' \
  --from-literal=user-password='YourUserPassword123!'
```

### 2.3 MySQL StatefulSet 배포

```yaml
# mysql-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: jk-querypie
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          ports:
            - containerPort: 3306
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: root-password
          volumeMounts:
            - name: mysql-storage
              mountPath: /var/lib/mysql
          resources:
            requests:
              memory: "1Gi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "1000m"
      volumes:
        - name: mysql-storage
          persistentVolumeClaim:
            claimName: mysql-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: jk-querypie
spec:
  ports:
    - port: 3306
  selector:
    app: mysql
  clusterIP: None
```

```bash
kubectl apply -f mysql-statefulset.yaml
```

### 2.4 데이터베이스 초기화

MySQL Pod가 Ready 상태가 되면 데이터베이스를 생성합니다.

```bash
# Wait for MySQL to be ready
kubectl wait --for=condition=ready pod/mysql-0 -n jk-querypie --timeout=300s

# Create databases
kubectl exec -it mysql-0 -n jk-querypie -- mysql -uroot -p'YourRootPassword123!' -e "
CREATE DATABASE IF NOT EXISTS querypie CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS querypie_log CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS querypie_snapshot CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'querypie'@'%' IDENTIFIED BY 'YourUserPassword123!';
GRANT ALL PRIVILEGES ON querypie.* TO 'querypie'@'%';
GRANT ALL PRIVILEGES ON querypie_log.* TO 'querypie'@'%';
GRANT ALL PRIVILEGES ON querypie_snapshot.* TO 'querypie'@'%';
FLUSH PRIVILEGES;
"
```

---

## 3. Redis 설치

세션 및 캐시 저장용 Redis를 설치합니다.

### 3.1 Redis Secret 생성

```bash
kubectl create secret generic redis-secret \
  -n jk-querypie \
  --from-literal=redis-password='YourRedisPassword123!'
```

### 3.2 Redis Deployment 배포

```yaml
# redis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: jk-querypie
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: redis:7-alpine
          command:
            - redis-server
            - --requirepass
            - $(REDIS_PASSWORD)
          ports:
            - containerPort: 6379
          env:
            - name: REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: redis-secret
                  key: redis-password
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: jk-querypie
spec:
  ports:
    - port: 6379
  selector:
    app: redis
```

```bash
kubectl apply -f redis-deployment.yaml
```

---

## 4. QueryPie 설치

### 4.1 Docker Registry Secret 생성

QueryPie 이미지를 가져오기 위한 인증 정보를 등록합니다.

```bash
kubectl create secret docker-registry querypie-regcred \
  -n jk-querypie \
  --docker-server=harbor.chequer.io \
  --docker-username='{your-username}' \
  --docker-password='{your-password}'
```

> **Note:** harbor.chequer.io 계정 정보는 QueryPie 담당자에게 문의하세요.

### 4.2 Helm Repository 추가

```bash
helm repo add querypie https://chequer-io.github.io/querypie-helm-charts
helm repo update
```

### 4.3 Values 파일 작성

`querypie-values.yaml` 파일을 생성합니다:

```yaml
# querypie-values.yaml

# Image configuration
image:
  registry: harbor.chequer.io
  pullSecrets:
    - name: querypie-regcred

# External URL (must match your domain)
externalURL: "https://jk-acp.tpm.querypie.io"

# Database configuration
database:
  host: mysql.jk-querypie.svc.cluster.local
  port: 3306
  username: querypie
  password: "YourUserPassword123!"
  database: querypie
  logDatabase: querypie_log
  snapshotDatabase: querypie_snapshot

# Redis configuration
redis:
  host: redis.jk-querypie.svc.cluster.local
  port: 6379
  password: "YourRedisPassword123!"

# Security keys (generate your own secure keys)
security:
  agentSecret: "your-agent-secret-key-min-32-chars!"
  kek: "your-kek-key-min-32-characters-here!"

# Ingress configuration (ALB)
ingress:
  enabled: true
  className: alb
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: "${CERT_ARN}"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/healthcheck-path: /health
  hosts:
    - host: jk-acp.tpm.querypie.io
      paths:
        - path: /
          pathType: Prefix

# Resource configuration
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### 4.4 Helm 설치

```bash
# Set certificate ARN as environment variable
export CERT_ARN=$(aws acm list-certificates --region ap-northeast-2 --profile 142605707876_AWSAdministratorAccess \
  --query "CertificateSummaryList[?DomainName=='jk-acp.tpm.querypie.io'].CertificateArn" --output text)

# Install with CERT_ARN substitution in values file
envsubst < querypie-values.yaml | helm upgrade --install querypie querypie/querypie \
  -n jk-querypie \
  -f -
```

### 4.5 설치 확인

```bash
kubectl get pods -n jk-querypie
kubectl get ingress -n jk-querypie
kubectl get svc -n jk-querypie
```

---

## 5. 데이터베이스 마이그레이션

QueryPie Pod가 준비되면 데이터베이스 마이그레이션을 실행합니다.

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=querypie -n jk-querypie --timeout=300s

# Run database migration
kubectl exec -it deployments/querypie-tools -n jk-querypie -- /app/script/migrate.sh runall
```

---

## 6. Route53 DNS 설정

### 6.1 ALB DNS 이름 확인

```bash
kubectl get ingress -n jk-querypie -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

### 6.2 Route53 레코드 생성

```bash
# Get Hosted Zone ID (tpm.querypie.io)
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --profile 142605707876_AWSAdministratorAccess \
  --query "HostedZones[?Name=='tpm.querypie.io.'].Id" --output text | cut -d'/' -f3)

# Get ALB DNS name
ALB_DNS=$(kubectl get ingress -n jk-querypie -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# ALB Hosted Zone ID (ap-northeast-2)
ALB_ZONE_ID="ZWKZPGTI48KDX"

# Create Route53 record
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

## 7. 접속 확인

### 7.1 DNS 전파 확인

```bash
dig jk-acp.tpm.querypie.io
```

### 7.2 HTTPS 접속 테스트

```bash
curl -I https://jk-acp.tpm.querypie.io
```

### 7.3 브라우저 접속

https://jk-acp.tpm.querypie.io 로 접속하여 QueryPie ACP 로그인 화면이 표시되는지 확인합니다.

---

## 정리 (삭제)

```bash
# Delete QueryPie
helm uninstall querypie -n jk-querypie

# Delete Redis
kubectl delete -f redis-deployment.yaml

# Delete MySQL
kubectl delete -f mysql-statefulset.yaml
kubectl delete -f mysql-pvc.yaml

# Delete secrets
kubectl delete secret mysql-secret redis-secret querypie-regcred -n jk-querypie

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

# Check Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Pod가 시작되지 않는 경우

```bash
# Check pod status
kubectl describe pod -n jk-querypie

# Check logs
kubectl logs -n jk-querypie <pod-name>
```

### ImagePullBackOff 오류

- `querypie-regcred` Secret이 올바르게 생성되었는지 확인
- harbor.chequer.io 인증 정보가 유효한지 확인

### 데이터베이스 연결 실패

```bash
# Test MySQL connection
kubectl exec -it mysql-0 -n jk-querypie -- mysql -uquerypie -p'YourUserPassword123!' -e "SHOW DATABASES;"

# Test Redis connection
kubectl exec -it deploy/redis -n jk-querypie -- redis-cli -a 'YourRedisPassword123!' PING
```

---

## 참고 링크

- [QueryPie 공식 EKS 설치 문서](https://docs.querypie.com/ko/installation/installation/installing-on-aws-eks)
- [Helm 차트 문서](https://chequer-io.github.io/querypie-helm-charts/)
