#!/bin/bash

# Trino + MySQL + PostgreSQL Docker 환경 자동화 스크립트
# 사용법: ./setup-trino.sh

set -e

echo "🚀 Trino + MySQL + PostgreSQL Docker 환경 설정을 시작합니다..."

# 1. 디렉토리 구조 생성
echo "📁 디렉토리 구조 생성 중..."
mkdir -p trino-stack/{trino/etc/catalog,mysql/data,postgresql/data}
cd trino-stack

# 2. Docker Compose 파일 생성
echo "📝 Docker Compose 파일 생성 중..."
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  mysql:
    image: mysql:8
    container_name: trino-mysql
    environment:
      MYSQL_ROOT_PASSWORD: Querypie1!
      MYSQL_DATABASE: testdb
    ports:
      - "3308:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./mysql/init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - trino-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

  postgresql:
    image: postgres:13
    container_name: trino-postgresql
    environment:
      POSTGRES_DB: testdb
      POSTGRES_USER: querypie
      POSTGRES_PASSWORD: Querypie1!
    ports:
      - "5434:5432"
    volumes:
      - postgresql_data:/var/lib/postgresql/data
      - ./postgresql/init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - trino-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U trino -d testdb"]
      interval: 10s
      timeout: 5s
      retries: 5

  trino:
    image: trinodb/trino:latest
    container_name: trino-coordinator
    ports:
      - "8080:8080"
    volumes:
      - ./trino/etc:/etc/trino
    networks:
      - trino-network
    depends_on:
      mysql:
        condition: service_healthy
      postgresql:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/v1/info || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  mysql_data:
  postgresql_data:

networks:
  trino-network:
    driver: bridge
EOF

# 3. Trino 설정 파일들 생성
echo "⚙️ Trino 설정 파일 생성 중..."

# config.properties
cat > trino/etc/config.properties <<'EOF'
coordinator=true
node-scheduler.include-coordinator=true
http-server.http.port=8080
query.max-memory=1GB
query.max-memory-per-node=256MB
discovery-server.enabled=true
discovery.uri=http://trino-coordinator:8080
node.environment=production
EOF

# jvm.config
cat > trino/etc/jvm.config <<'EOF'
-server
-Xmx2G
-XX:+UseG1GC
-XX:+UseGCOverheadLimit
-XX:+ExplicitGCInvokesConcurrent
-XX:+HeapDumpOnOutOfMemoryError
-XX:+ExitOnOutOfMemoryError
-Djdk.attach.allowAttachSelf=true
EOF

# node.properties
cat > trino/etc/node.properties <<'EOF'
node.environment=production
node.id=ffffffff-ffff-ffff-ffff-ffffffffffff
node.data-dir=/data/trino
EOF

# log.properties
cat > trino/etc/log.properties <<'EOF'
io.trino=INFO
EOF

# MySQL 카탈로그 설정 (Docker 내부 네트워크 사용)
cat > trino/etc/catalog/mysql.properties <<'EOF'
connector.name=mysql
connection-url=jdbc:mysql://mysql:3306
connection-user=root
connection-password=Querypie1!
EOF

# PostgreSQL 카탈로그 설정 (Docker 내부 네트워크 사용)
cat > trino/etc/catalog/postgresql.properties <<'EOF'
connector.name=postgresql
connection-url=jdbc:postgresql://postgresql:5432/testdb
connection-user=querypie
connection-password=Querypie1!
EOF

# 4. MySQL 초기 데이터 스크립트 생성
echo "🗄️ MySQL 초기 데이터 스크립트 생성 중..."
cat > mysql/init.sql <<'EOF'
USE testdb;

CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL,
    price DECIMAL(10,2) NOT NULL
);

INSERT INTO users (username, email) VALUES
('john_doe', 'john.doe@example.com'),
('jane_smith', 'jane.smith@example.com'),
('peter_jones', 'peter.jones@example.com');

INSERT INTO products (product_name, price) VALUES
('Laptop', 1200.00),
('Mouse', 25.00),
('Keyboard', 75.00),
('Monitor', 300.00);
EOF

# 5. PostgreSQL 초기 데이터 스크립트 생성
echo "🗄️ PostgreSQL 초기 데이터 스크립트 생성 중..."
cat > postgresql/init.sql <<'EOF'
CREATE TABLE IF NOT EXISTS orders (
    order_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

INSERT INTO categories (category_name) VALUES
('Electronics'),
('Peripherals'),
('Books');

INSERT INTO orders (user_id, product_id, quantity) VALUES
(1, 1, 1), -- john_doe ordered Laptop
(2, 2, 2), -- jane_smith ordered 2 Mice
(1, 3, 1), -- john_doe ordered Keyboard
(3, 4, 1), -- peter_jones ordered Monitor
(2, 1, 1); -- jane_smith ordered Laptop
EOF

# 6. 편의 스크립트들 생성
echo "🛠️ 편의 스크립트 생성 중..."

# start.sh
cat > start.sh <<'EOF'
#!/bin/bash
echo "🚀 Trino + MySQL + PostgreSQL 환경 시작 중..."
docker-compose up -d
echo "✅ 서비스가 시작되었습니다."
echo "📊 Trino UI: http://localhost:8080"
echo "🗄️ MySQL: localhost:3308 (root/Querypie1!)"
echo "🐘 PostgreSQL: localhost:5432 (querypie/Querypie1!)"
echo ""
echo "서비스 상태 확인 중..."
sleep 10 # Give services some time to become healthy
docker-compose ps
echo ""
echo "Trino CLI로 연결하려면 다음 명령어를 실행하세요:"
echo "docker exec -it trino-coordinator trino --server http://localhost:8080 --catalog mysql --schema testdb"
echo "또는"
echo "docker exec -it trino-coordinator trino --server http://localhost:8080 --catalog postgresql --schema public"
echo ""
echo "테스트 쿼리를 실행하려면:"
echo "docker exec -it trino-coordinator trino --server http://localhost:8080 -f /etc/trino/test-queries.sql"
EOF
chmod +x start.sh

# stop.sh
cat > stop.sh <<'EOF'
#!/bin/bash
echo "🛑 Trino + MySQL + PostgreSQL 환경 중지 중..."
docker-compose down
echo "✅ 서비스가 중지되었습니다."
EOF
chmod +x stop.sh

# 7. 테스트 쿼리 스크립트 생성
echo "📝 테스트 쿼리 스크립트 생성 중..."
cat > trino/etc/test-queries.sql <<'EOF'
-- Trino CLI에서 실행할 테스트 쿼리들

-- 1. Show Catalogs
SHOW CATALOGS;

-- 2. MySQL Schemas and Tables
USE mysql.testdb;
SHOW SCHEMAS;
SHOW TABLES;
SELECT * FROM users LIMIT 5;
SELECT * FROM products LIMIT 5;

-- 3. PostgreSQL Schemas and Tables
USE postgresql.public;
SHOW SCHEMAS;
SHOW TABLES;
SELECT * FROM orders LIMIT 5;
SELECT * FROM categories LIMIT 5;

-- 4. Join Query: Users from MySQL and Orders from PostgreSQL
-- This query joins data across different databases (MySQL and PostgreSQL)
-- to show which users ordered which products, quantities, and their total spending.
SELECT
    u.username,
    u.email,
    p.product_name,
    o.quantity,
    (o.quantity * p.price) AS total_item_price,
    o.order_date
FROM
    mysql.testdb.users AS u
JOIN
    postgresql.public.orders AS o ON u.user_id = o.user_id
JOIN
    mysql.testdb.products AS p ON o.product_id = p.product_id
ORDER BY
    u.username, o.order_date;

-- 5. Aggregation Query: Total spending per user (across both MySQL and PostgreSQL data)
SELECT
    u.username,
    u.email,
    SUM(o.quantity * p.price) AS total_spent
FROM
    mysql.testdb.users AS u
JOIN
    postgresql.public.orders AS o ON u.user_id = o.user_id
JOIN
    mysql.testdb.products AS p ON o.product_id = p.product_id
GROUP BY
    u.user_id, u.username, u.email
ORDER BY
    total_spent DESC;

-- 6. Combined Query: Products and their categories (assuming a product_category relationship if available)
-- This query is illustrative. If categories were in MySQL and products in PostgreSQL, it would be another cross-database join.
-- For now, let's show an example of a simple join within a single catalog if appropriate, or just select from each.

-- Example: Get all products and their associated categories (if categories were related by ID)
-- (Assuming 'products' table in MySQL has a category_id and 'categories' table in PostgreSQL has category_id and category_name)
SELECT
    p.product_name,
    c.category_name,
    p.price
FROM
    mysql.testdb.products AS p,
    postgresql.public.categories AS c -- This is a cross join for illustration, assumes a linking column in real data
WHERE
    p.product_id = 1 AND c.category_id = 1; -- Placeholder for a join condition if actual linking column exists

-- More realistic example of cross-catalog join with filtering:
-- Find users who ordered products from the 'Electronics' category.
SELECT DISTINCT
    u.username,
    u.email
FROM
    mysql.testdb.users AS u
JOIN
    postgresql.public.orders AS o ON u.user_id = o.user_id
JOIN
    mysql.testdb.products AS p ON o.product_id = p.product_id
JOIN
    postgresql.public.categories AS cat ON p.product_id = cat.category_id -- This join condition needs to match actual data
WHERE
    cat.category_name = 'Electronics';

-- Note: The join condition `p.product_id = cat.category_id` in the above query is a placeholder.
-- In a real-world scenario, you would need a common linking column between products and categories.
-- For instance, if 'products' table in MySQL had a 'category_id' column:
-- JOIN postgresql.public.categories AS cat ON p.category_id = cat.category_id
EOF

echo "✅ Trino + MySQL + PostgreSQL 환경 설정이 완료되었습니다!"
echo "➡️ 'cd trino-stack' 명령어로 이동하여 'start.sh' 스크립트를 실행하여 시작하세요."