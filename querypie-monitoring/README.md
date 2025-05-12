# QueryPie 모니터링 설정 가이드

실행 중인 QueryPie 인스턴스에 대한 모니터링 설정 가이드입니다.
QueryPie 인스턴스가 다수일 경우 각각의 노드에서 실행해줘야 합니다.

이 가이드는 Prometheus, Grafana, Process Exporter를 사용하여 QueryPie 모니터링 시스템을 설정하는 방법을 설명합니다. 모니터링 시스템은 QueryPie의 성능, 리소스 사용량, 데이터베이스 활동에 대한 실시간 인사이트를 제공합니다.

## 사전 요구사항

- QueryPie 10.1.7 이상 버전 설치
- Docker 및 Docker Compose 설치
- QueryPie MetaDB 접근 권한

## 설치 단계

### 1. 모니터링 스크립트 다운로드
QueryPie Docker 인스턴스가 설치되어 있는 노드에서 다음 명령어를 실행합니다:
```bash
curl -O https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/querypie-monitoring/monitoring.sh
chmod +x monitoring.sh
```

### 2. MetaDB 설정
MetaDB 연결 설정은 두 가지 방법으로 구성할 수 있습니다:

#### 방법 1: 환경 변수 사용
설정 스크립트를 실행하기 전에 다음 환경 변수를 설정합니다:
```bash
export MYSQL_HOST=<메타DB_호스트>
export PORT=<메타DB_포트>
export MYSQL_USER=<메타DB_사용자>
export MYSQL_PASS=<메타DB_비밀번호>
export MYSQL_DB="querypie_log"
```

#### 방법 2: 기본값 사용
환경 변수를 설정하지 않으면 스크립트는 다음 기본값을 사용합니다:
- MYSQL_HOST: 127.0.0.1
- PORT: 3306
- MYSQL_USER: querypie
- MYSQL_PASS: Querypie1!
- MYSQL_DB: querypie_log

### 3. 모니터링 환경 초기화
```bash
./monitoring.sh setup
```

### 4. 모니터링 서비스 시작
각 QueryPie 인스턴스에서 다음 명령어를 실행합니다:
```bash
./monitoring.sh up
```

이 명령어는 다음 컴포넌트들을 실행합니다:
- Prometheus (메트릭 수집)
- Grafana (대시보드 시각화)
- procstat (proc 메트릭)

## 상태 확인

### 접속 확인
- Grafana: `http://{instance-ip}:3000/dashboards`
- Prometheus: `http://{instance-ip}:9090`

### 메트릭 수집 확인
Prometheus에서 다음 타겟들의 상태를 확인:
- QueryPie (80)
- procstat

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