# Trino + MySQL + PostgreSQL Docker 환경 자동화

Docker를 사용하여 Trino, MySQL, PostgreSQL을 통합한 완전한 분석 환경을 구축하는 자동화 스크립트입니다.

## 📋 개요

이 프로젝트는 다음 구성 요소들을 포함한 완전한 데이터 분석 스택을 제공합니다:

- **Trino**: 분산 SQL 쿼리 엔진 (포트 8080)
- **MySQL**: 관계형 데이터베이스 (포트 3308)
- **PostgreSQL**: 관계형 데이터베이스 (포트 5434)

## 🚀 빠른 시작

### 1. 사전 요구사항

- Docker
- Docker Compose
- Bash (Linux/macOS/WSL)

### 2. 설치 및 실행

```bash
# 스크립트 다운로드
curl -O https://raw.githubusercontent.com/querypie/tpm/main/datasource/trino/setup-trino.sh

# 스크립트에 실행 권한 부여
chmod +x setup-trino.sh

# 환경 설정 실행
./setup-trino.sh

# 생성된 디렉토리로 이동
cd trino-stack

# 서비스 시작
./start.sh
```

### 3. 접속 정보

| 서비스 | URL/주소 | 사용자 | 비밀번호 |
|--------|----------|---------|----------|
| Trino UI | http://localhost:8080 | - | - |
| MySQL | localhost:3308 | root | Querypie1! |
| PostgreSQL | localhost:5434 | querypie | Querypie1! |

## 📊 데이터 구조

### MySQL (testdb)

#### users 테이블
- `user_id` (INT, PRIMARY KEY, AUTO_INCREMENT)
- `username` (VARCHAR(100), UNIQUE)
- `email` (VARCHAR(100), UNIQUE)
- `registration_date` (TIMESTAMP)

#### products 테이블
- `product_id` (INT, PRIMARY KEY, AUTO_INCREMENT)
- `product_name` (VARCHAR(200))
- `price` (DECIMAL(10,2))

### PostgreSQL (testdb/public)

#### orders 테이블
- `order_id` (SERIAL, PRIMARY KEY)
- `user_id` (INT)
- `product_id` (INT)
- `quantity` (INT)
- `order_date` (TIMESTAMP)

#### categories 테이블
- `category_id` (SERIAL, PRIMARY KEY)
- `category_name` (VARCHAR(100), UNIQUE)

```text
+--------------------+                   +--------------------+
| MySQL: users       |                   | PostgreSQL: orders |
|--------------------|                   |--------------------|
| PK user_id   <-----+-------------------| FK user_id         |
|   username         |                   | PK order_id        |
|   email            |                   | FK product_id      |
|   registration_date|                   |   quantity         |
+--------------------+                   |   order_date       |
       ^                                 +--------------------+
       |                                          |
       |  (Placed by)                             | (Contains)
       |                                          |
+--------------------+                            |
| MySQL: products    |                            |
|--------------------|                            |
| PK product_id  <---+----------------------------+
|   product_name     |
|   price            |
+--------------------+

+------------------------+
| PostgreSQL: categories |
|------------------------|
| PK category_id     <---+-- (Conceptual link, if products had category_id)
|   category_name        |
+------------------------+
```

## 🔧 사용법

### Trino CLI 접속

```bash
# MySQL 카탈로그로 접속
docker exec -it trino-coordinator trino --server http://localhost:8080 --catalog mysql --schema testdb

# PostgreSQL 카탈로그로 접속
docker exec -it trino-coordinator trino --server http://localhost:8080 --catalog postgresql --schema public
```

### 테스트 쿼리 실행

```bash
# 미리 준비된 테스트 쿼리 실행
docker exec -it trino-coordinator trino --server http://localhost:8080 -f /etc/trino/test-queries.sql
```

### 크로스 데이터베이스 쿼리 예제

```sql
-- MySQL과 PostgreSQL 데이터를 결합한 쿼리
SELECT 
    u.username,
    u.email,
    p.product_name,
    o.quantity,
    (o.quantity * p.price) AS total_price
FROM 
    mysql.testdb.users AS u
JOIN 
    postgresql.public.orders AS o ON u.user_id = o.user_id
JOIN 
    mysql.testdb.products AS p ON o.product_id = p.product_id
ORDER BY 
    u.username;
```

## 📁 프로젝트 구조

```
trino-stack/
├── docker-compose.yml          # Docker Compose 설정
├── start.sh                    # 서비스 시작 스크립트
├── stop.sh                     # 서비스 중지 스크립트
├── trino/
│   ├── etc/
│   │   ├── config.properties   # Trino 메인 설정
│   │   ├── jvm.config         # JVM 옵션
│   │   ├── node.properties    # 노드 설정
│   │   ├── log.properties     # 로그 설정
│   │   ├── test-queries.sql   # 테스트 쿼리
│   │   └── catalog/
│   │       ├── mysql.properties      # MySQL 커넥터
│   │       └── postgresql.properties # PostgreSQL 커넥터
├── mysql/
│   └── init.sql               # MySQL 초기 데이터
└── postgresql/
    └── init.sql               # PostgreSQL 초기 데이터
```

## 🛠️ 관리 명령어

### 서비스 시작
```bash
./start.sh
```

### 서비스 중지
```bash
./stop.sh
```

### 서비스 상태 확인
```bash
docker-compose ps
```

### 로그 확인
```bash
# 모든 서비스 로그
docker-compose logs

# 특정 서비스 로그
docker-compose logs trino
docker-compose logs mysql
docker-compose logs postgresql
```

### 완전 정리 (데이터 포함)
```bash
docker-compose down -v
```

## 🔍 트러블슈팅

### 일반적인 문제들

1. **포트 충돌**
    - 기본 포트들이 사용 중인 경우 `docker-compose.yml`에서 포트 변경

2. **메모리 부족**
    - `trino/etc/jvm.config`에서 `-Xmx2G`를 더 낮은 값으로 조정

3. **서비스가 시작되지 않는 경우**
   ```bash
   docker-compose logs [서비스명]
   ```

4. **데이터베이스 연결 실패**
    - Health check 대기 시간 증가 필요할 수 있음

### 유용한 디버깅 명령어

```bash
# 컨테이너 내부 접속
docker exec -it trino-coordinator bash
docker exec -it trino-mysql bash
docker exec -it trino-postgresql bash

# MySQL 직접 접속
docker exec -it trino-mysql mysql -u root -p

# PostgreSQL 직접 접속
docker exec -it trino-postgresql psql -U querypie -d testdb
```