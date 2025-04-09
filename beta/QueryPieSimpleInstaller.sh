#!/bin/bash

# QueryPie Simple Installer
# Created: 2025-04-05

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 버전 형식 검증 함수
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}오류: 버전은 major.minor.patch 형식이어야 합니다 (예: 10.2.7)${NC}"
        return 1
    fi
    return 0
}

# 도커 실행 권한 확인 함수
check_docker_permission() {
    if docker ps &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 입력값 처리 함수
process_input() {
    local key=$1
    local current_value=$2
    local new_value=""
    
    if [ -n "$current_value" ]; then
        echo -e "현재 ${key} 값: $current_value"
        read -p "Enter를 누르면 현재 값을 유지합니다. 변경하려면 새 값을 입력하세요: " new_value
        if [ -z "$new_value" ]; then
            new_value=$current_value
        fi
    else
        read -p "${key} 값을 입력하세요: " new_value
    fi
    
    echo "$new_value"
}

# 사용법 체크
if [ $# -ne 1 ]; then
    echo "사용법: $0 <버전>"
    echo "  버전: major.minor.patch 형식 (예: 10.2.7)"
    exit 1
fi

NEW_VERSION=$1

# 버전 형식 검증
if ! validate_version "$NEW_VERSION"; then
    exit 1
fi

# 버전 변수 설정
IFS='.' read -r MAJOR MINOR PATCH <<< "$NEW_VERSION"
export DOWNLOAD_VERSION="${MAJOR}.${MINOR}.x"
export QP_VERSION="$NEW_VERSION"

echo -e "${GREEN}QueryPie 설치를 시작합니다. 버전: $QP_VERSION${NC}"

# setup.sh 다운로드 및 실행
echo -e "\n${YELLOW}설치 스크립트를 다운로드합니다...${NC}"
curl -L https://dl.querypie.com/releases/compose/setup.sh -o setup.sh
chmod +x setup.sh

echo -e "\n${YELLOW}설치 스크립트를 실행합니다...${NC}"
./setup.sh

# 도커 실행 권한 확인
if ! check_docker_permission; then
    echo -e "\n${YELLOW}도커 실행 권한이 필요합니다. 권한을 추가합니다...${NC}"
    sudo usermod -aG docker $USER
    echo -e "${RED}터미널에 다시 로그인한 후 스크립트를 다시 실행해주세요.${NC}"
    exit 1
fi

# 실행 위치로 이동
TARGET_DIR="./querypie/$NEW_VERSION"
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}오류: $TARGET_DIR 디렉토리가 존재하지 않습니다.${NC}"
    exit 1
fi

cd "$TARGET_DIR"

if [ ! -f "compose-env" ]; then
    echo -e "${RED}오류: compose-env 파일이 존재하지 않습니다.${NC}"
    exit 1
fi

# 하버 레지스트리 로그인
echo -e "\n${YELLOW}하버 레지스트리에 로그인합니다...${NC}"
while true; do
    # 직접 로그인 명령어 실행
    docker login harbor.chequer.io
    login_status=$?
    
    if [ $login_status -eq 0 ]; then
        # 로그인 성공 확인
        if docker login harbor.chequer.io 2>&1 | grep -q "Authenticating with existing credentials"; then
            echo -e "${GREEN}로그인 성공${NC}"
            break
        fi
    fi
    
    echo -e "${RED}로그인 실패. 다시 시도하시겠습니까? (y/n)${NC}"
    read -r retry
    if [[ ! "$retry" =~ ^[Yy]$ ]]; then
        echo -e "${RED}설치를 중단합니다.${NC}"
        exit 1
    fi
done

# compose-env 파일 백업
if [ ! -f "compose-env.backup" ]; then
    cp compose-env compose-env.backup
    echo -e "${GREEN}compose-env 파일이 백업되었습니다.${NC}"
else
    echo -e "${YELLOW}compose-env.backup 파일이 이미 존재합니다.${NC}"
fi

# 환경 변수 설정
echo -e "\n${YELLOW}환경 변수를 설정합니다...${NC}"

# 필수 입력 키 목록
REQUIRED_KEYS=(
    "AGENT_SECRET"
    "KEY_ENCRYPTION_KEY"
    "QUERYPIE_WEB_URL"
    "DB_HOST"
    "DB_PORT"
    "DB_CATALOG"
    "LOG_DB_CATALOG"
    "ENG_DB_CATALOG"
    "DB_USERNAME"
    "DB_PASSWORD"
    "DB_MAX_CONNECTION_SIZE"
    "REDIS_HOST"
    "REDIS_PORT"
    "REDIS_CONNECTION_MODE"
    "REDIS_NODES"
    "REDIS_PASSWORD"
)

# 임시 파일 생성
tmp_file=$(mktemp)

# compose-env 파일의 모든 줄을 임시 파일로 복사
cp compose-env "$tmp_file"

# 값 검증 함수
validate_value() {
    local key=$1
    local value=$2

    # REDIS_PASSWORD 빈 값 확인
    if [ "$key" = "REDIS_PASSWORD" ]; then
        if [ -z "$value" ]; then
            echo -e "${YELLOW}경고: REDIS_PASSWORD가 비어있습니다. 보안상 권장되지 않습니다.${NC}"
            while true; do
                read -p "빈 값으로 계속 진행하시겠습니까? (y/n): " confirm
                case $confirm in
                    [Yy]* )
                        return 0;;
                    [Nn]* )
                        return 1;;
                    * )
                        echo "y 또는 n을 입력해주세요.";;
                esac
            done
        fi
        return 0
    fi

    # REDIS_CONNECTION_MODE 검증
    if [ "$key" = "REDIS_CONNECTION_MODE" ]; then
        if [ "$value" != "STANDALONE" ] && [ "$value" != "CLUSTER" ]; then
            echo -e "${RED}오류: REDIS_CONNECTION_MODE는 STANDALONE 또는 CLUSTER만 가능합니다.${NC}"
            return 1
        fi
        return 0
    fi

    # AGENT_SECRET 검증
    if [ "$key" = "AGENT_SECRET" ]; then
        if [ ${#value} -ne 32 ]; then
            echo -e "${RED}오류: AGENT_SECRET은 정확히 32자여야 합니다. 현재 길이: ${#value}${NC}"
            return 1
        fi
        return 0
    fi

    # QUERYPIE_WEB_URL 검증
    if [ "$key" = "QUERYPIE_WEB_URL" ]; then
        if [[ ! "$value" =~ ^https?:// ]]; then
            echo -e "${RED}오류: QUERYPIE_WEB_URL은 http:// 또는 https://로 시작해야 합니다.${NC}"
            return 1
        fi
        return 0
    fi

    # 나머지 키들은 빈 값 체크
    if [ -z "$value" ]; then
        echo -e "${RED}오류: $key는 필수 값입니다. 값을 입력해주세요.${NC}"
        return 1
    fi

    return 0
}

# 각 필수 키에 대해 값 입력 받기
for key in "${REQUIRED_KEYS[@]}"; do
    # compose-env 파일에 키가 있는지 확인
    if ! grep -q "^$key=" "compose-env"; then
        continue
    fi

    while true; do
        # 현재 값 확인
        current_value=$(grep "^$key=" "$tmp_file" | cut -d'=' -f2- || echo "")
        
        # 키에 대한 설명 출력
        case $key in
            "AGENT_SECRET")
                echo -e "\n${YELLOW}AGENT_SECRET${NC}"
                echo "QueryPie 클라이언트 에이전트와 QueryPie 간의 통신을 암호화하기 위한 비밀 키"
                echo "정확히 32자여야 합니다."
                ;;
            "KEY_ENCRYPTION_KEY")
                echo -e "\n${YELLOW}KEY_ENCRYPTION_KEY${NC}"
                echo "데이터베이스 연결 문자열 및 SSH 개인 키와 같은 중요한 정보를 암호화하는 데 사용되는 키"
                echo "한 번 설정하면 변경할 수 없습니다."
                ;;
            "QUERYPIE_WEB_URL")
                echo -e "\n${YELLOW}QUERYPIE_WEB_URL${NC}"
                echo "QueryPie의 기본 URL (http:// 또는 https://로 시작)"
                ;;
            "REDIS_PASSWORD")
                echo -e "\n${YELLOW}REDIS_PASSWORD${NC}"
                echo "Redis 연결을 위한 비밀번호 (빈 값 허용)"
                ;;
            "REDIS_CONNECTION_MODE")
                echo -e "\n${YELLOW}REDIS_CONNECTION_MODE${NC}"
                echo "Redis 연결 모드 (STANDALONE 또는 CLUSTER)"
                ;;
            *)
                echo -e "\n${YELLOW}$key${NC}"
                ;;
        esac

        # 현재 값이 있으면 표시
        if [ -n "$current_value" ]; then
            echo -e "현재 값: ${RED}$current_value${NC}"
        fi

        # 새 값 입력 받기
        read -p "새 값을 입력하세요 (현재 값 유지: Enter): " new_value

        # 입력값이 없으면 현재 값 검증
        if [ -z "$new_value" ]; then
            if [ -n "$current_value" ]; then
                new_value=$current_value
            elif [ "$key" = "REDIS_PASSWORD" ]; then
                new_value=""
            else
                echo -e "${RED}값이 입력되지 않았습니다. 새로운 값을 입력해주세요.${NC}"
                continue
            fi
        fi

        # 값 검증
        if validate_value "$key" "$new_value"; then
            # 파일에서 해당 키의 값 업데이트
            sed -i.bak "s|^$key=.*|$key=$new_value|" "$tmp_file" && rm -f "$tmp_file.bak"
            break
        fi
    done
done

# 임시 파일을 원본으로 이동
mv "$tmp_file" compose-env

echo -e "${GREEN}환경 변수 설정이 완료되었습니다.${NC}"

echo -e "\n${YELLOW}데이터베이스를 시작합니다...${NC}"
docker-compose --env-file compose-env --profile database up -d

echo -e "\n${YELLOW}10초 대기 중...${NC}"
sleep 10

echo -e "\n${YELLOW}tools를 시작합니다...${NC}"
docker-compose --env-file compose-env --profile tools up -d

echo -e "\n${YELLOW}10초 대기 중...${NC}"
sleep 10

echo -e "\n${YELLOW}마이그레이션을 실행합니다...${NC}"
docker exec -it querypie-tools-1 /app/script/migrate.sh runall

# 라이선스 파일 처리
echo -e "\n${YELLOW}라이선스 파일을 확인합니다...${NC}"

# 스크립트 실행 위치의 .crt 파일 찾기
current_dir=$(pwd)
cd ../..
crt_files=(*.crt)

if [ -e "${crt_files[0]}" ]; then
    echo -e "${GREEN}발견된 라이선스 파일:${NC}"
    for file in *.crt; do
        echo "- $file"
        cp "$file" "$current_dir/"
    done
    cd "$current_dir"
    echo -e "\n${YELLOW}라이선스 파일이 현재 디렉토리로 복사되었습니다.${NC}"
else
    cd "$current_dir"
    echo -e "${RED}상위 디렉토리에서 라이선스 파일(.crt)을 찾을 수 없습니다.${NC}"
fi

# 현재 디렉토리의 .crt 파일 목록 표시
echo -e "\n${YELLOW}현재 디렉토리의 라이선스 파일:${NC}"
if ls *.crt >/dev/null 2>&1; then
    for file in *.crt; do
        echo "- $file"
    done
else
    echo -e "${RED}현재 디렉토리에 라이선스 파일이 없습니다.${NC}"
fi

# 라이선스 추가 방식 선택
echo -e "\n${YELLOW}라이선스를 추가합니다...${NC}"
while true; do
    echo "라이선스 파일명을 입력하세요 :"
    read -p "> " license_file

    if [ "$license_file" = "querypie" ]; then
        echo -e "\n${YELLOW}QueryPie 내부 라이선스를 추가합니다...${NC}"
        docker exec -it querypie-tools-1 /app/script/license.sh add
        break
    elif [ -f "$license_file" ]; then
        echo -e "\n${YELLOW}라이선스 파일을 업로드합니다...${NC}"
        curl -XPOST 127.0.0.1:8050/license/upload -F "file=@$license_file"
        break
    else
        echo -e "${RED}파일을 찾을 수 없습니다. 다시 시도하세요.${NC}"
    fi
done

echo -e "\n${YELLOW}tools를 종료합니다...${NC}"
docker-compose --env-file compose-env --profile tools down

echo -e "\n${YELLOW}QueryPie를 시작합니다...${NC}"
docker-compose --env-file compose-env --profile querypie up -d

echo -e "\n${GREEN}설치가 완료되었습니다. 로그를 확인합니다...${NC}"
docker logs -f querypie-app-1 