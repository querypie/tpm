# QueryPie 모니터링 설정 가이드

## 개요
QueryPie 모니터링은 Prometheus, Grafana, Process Exporter를 사용하여 QueryPie의 상태를 모니터링하는 시스템입니다.

## 설치 방법

### 1. 모니터링 디렉토리 생성 및 이동
```bash
mkdir querypie-monitoring
cd querypie-monitoring
```

### 2. 모니터링 스크립트 다운로드
```bash
curl -O https://raw.githubusercontent.com/querypie/tpm/main/querypie-monitoring/monitoring.sh
chmod +x monitoring.sh
```

### 3. 모니터링 환경 초기화
```bash
./monitoring.sh setup
```

### 4. 모니터링 서비스 시작
```bash
./monitoring.sh up
```

### 5. 모니터링 서비스 중지 (필요시)
```bash
./monitoring.sh down
```

## 대시보드 접속
- Grafana 대시보드: http://localhost:3000
- Prometheus 대시보드: http://localhost:9090

## 환경 변수 설정 (선택사항)
기본값을 변경하려면 다음 환경 변수를 설정할 수 있습니다:
```bash
export MYSQL_HOST="your-mysql-host"
export PORT="your-mysql-port"
export MYSQL_USER="your-mysql-user"
export MYSQL_PASS="your-mysql-password"
export MYSQL_DB="your-mysql-database"
```

## 주의사항
- QueryPie가 실행 중이어야 합니다
- Docker와 Docker Compose가 설치되어 있어야 합니다
- 포트 3000, 9090, 9256이 사용 가능해야 합니다
- QueryPie 버전 3.0.0 이상에서만 지원됩니다

## 사전 요구사항

- QueryPie 10.1.7 이상 버전 설치
- Docker 및 Docker Compose 설치
- QueryPie MetaDB 접근 권한

## 제공되는 대시보드

모니터링 시스템은 다음 세 가지 주요 대시보드를 제공합니다:

1. **QueryPie 상태 대시보드**
   - CPU 사용량
   - 메모리 사용량
   - 프로세스 상태
   - 시스템 리소스 메트릭

2. **QueryPie MetaDB 연결 대시보드**
   - 연결 풀 사용량
   - 데이터베이스 연결 통계
   - 연결 풀 상태 메트릭

3. **QueryPie 로그 대시보드**
   - SQL 실행 로그
   - 데이터 변경 추적
   - 인증 이벤트
   - 권한 변경 사항

## Prometheus 데이터 관리

### 데이터 보존 기간 설정

Prometheus 설정에서 데이터 보존 기간을 조정할 수 있습니다. `monitoring.yml` 파일의 prometheus 서비스 섹션을 수정:

```yaml
command:
  - '--config.file=/etc/prometheus/prometheus.yml'
  - '--storage.tsdb.path=/prometheus'
  - '--storage.tsdb.retention.time=15d'  # 데이터 보존 기간 (예: 15일)
  - '--storage.tsdb.retention.size=50GB' # 최대 저장 용량
  - '--web.enable-lifecycle'
```

### 디스크 사용량 모니터링

Prometheus 데이터 볼륨 상태 확인:
```bash
# 볼륨 사용량 확인
docker system df -v | grep prometheus_data

# 상세 용량 확인
sudo du -sh /var/lib/docker/volumes/querypie-monitoring_prometheus_data/_data
```

### 수동 데이터 정리

전체 데이터 삭제:
```bash
./monitoring.sh down
docker volume rm querypie-monitoring_prometheus_data
```

### 권장 설정

- 데이터 보존 기간: 15일
- 최대 저장 용량: 시스템 디스크의 20% 이하
- 정기적인 모니터링 권장: 디스크 사용량이 80% 초과 시 조치

## 모니터링 서비스 중지

모니터링 서비스를 중지하려면:
```bash
./monitoring.sh down
```

## 참고사항

- 이 모니터링 설정은 QueryPie 버전 10.1.7을 기준으로 합니다
- 버전 10.2.1에서 추가되는 메트릭은 별도의 가이드에서 제공될 예정입니다
- 모니터링 시스템은 다음 구성 요소를 사용합니다:
  - Prometheus (v3.0.0) - 메트릭 수집
  - Grafana (v11.3.1) - 시각화
  - Process Exporter - 프로세스 모니터링

## 주의사항

- 각 인스턴스별로 독립적인 모니터링 환경을 구성해야 합니다
- Grafana 대시보드는 Anonymous 접속이 활성화되어 있습니다 