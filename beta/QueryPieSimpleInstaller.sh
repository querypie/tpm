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
    echo -e "${GREEN}도커 실행 권한이 추가되었습니다.${NC}"
    echo -e "${YELLOW}권한 적용을 위해 터미널에서 로그아웃 후 다시 로그인이 필요합니다.${NC}"
    echo -e "${YELLOW}로그인 후 다음 명령어를 다시 실행해주세요:${NC}"
    echo -e "${GREEN}$0 $NEW_VERSION${NC}"
    echo -e "${RED}스크립트를 종료합니다. 로그아웃 후 다시 실행해주세요.${NC}"
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

# compose-env 파일에서 키 목록 읽기
get_compose_env_keys() {
    local compose_env_file="$1"
    if [ ! -f "$compose_env_file" ]; then
        echo -e "${RED}오류: compose-env 파일을 찾을 수 없습니다.${NC}"
        exit 1
    fi
    # compose-env 파일에서 키 목록 추출 (키=값 형식에서 키만 추출)
    grep -v '^#' "$compose_env_file" | grep '=' | cut -d'=' -f1
}

# 값 검증 함수
validate_value() {
    local key=$1
    local value=$2

    # 영문, 숫자, 특수문자만 허용
    if [[ ! $value =~ ^[a-zA-Z0-9[:punct:][:space:]]*$ ]]; then
        echo -e "${RED}오류: 영문, 숫자, 특수문자만 입력 가능합니다.${NC}"
        return 1
    fi

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

# 환경 변수 입력 처리 함수
handle_env_input() {
    local compose_env_file="compose-env"
    local temp_file="compose-env.temp"
    
    # compose-env 파일의 모든 내용을 임시 파일로 복사 (주석 포함)
    cp "$compose_env_file" "$temp_file"

    # compose-env 파일에서 키 목록 가져오기
    local compose_env_keys=($(get_compose_env_keys "$compose_env_file"))

    # REQUIRED_KEYS와 compose-env 파일 모두에 있는 키들만 처리
    for key in "${REQUIRED_KEYS[@]}"; do
        # compose-env에 없는 키는 건너뛰기
        if [[ ! " ${compose_env_keys[@]} " =~ " ${key} " ]]; then
            continue
        fi

        echo "" # 각 키 입력 전 빈 줄 추가
        local value=""
        local existing_value=""
        local key_exists=false
        
        # 기존 compose-env 파일에서 키가 있는지 확인
        if grep -q "^$key=" "$compose_env_file" 2>/dev/null; then
            key_exists=true
            # 값 읽어오기
            existing_value=$(grep "^$key=" "$compose_env_file" 2>/dev/null | cut -d'=' -f2-)
        fi

        # QUERYPIE_WEB_URL에 대한 안내 메시지
        if [ "$key" = "QUERYPIE_WEB_URL" ]; then
            echo -e "${YELLOW}QUERYPIE_WEB_URL은 http:// 또는 https://로 시작해야 합니다.${NC}"
        fi
        
        # 키가 있고 값이 있는 경우
        if [ "$key_exists" = true ] && [ -n "$existing_value" ]; then
            echo -e "현재 ${key} 값 ${RED}[${existing_value}]${NC}"
            echo -n "새 값을 입력하세요 (Enter를 누르면 현재 값 유지): "
            read -r value

            # Enter를 누른 경우 기존 값 유지
            if [ -z "$value" ]; then
                value="$existing_value"
            else
                # 새로운 값이 입력된 경우 검증
                while ! validate_value "$key" "$value"; do
                    echo -n "새 값을 입력하세요: "
                    read -r value
                    # Enter를 누른 경우 기존 값으로 복귀
                    if [ -z "$value" ]; then
                        value="$existing_value"
                        break
                    fi
                done
            fi

            # 값이 변경된 경우에만 임시 파일 업데이트
            if [ "$value" != "$existing_value" ]; then
                # 임시 파일 업데이트
                awk -v key="$key" -v val="$value" '
                    $0 ~ "^"key"=" { print key"="val; next }
                    { print }
                ' "$temp_file" > "$temp_file.new" 2>/dev/null && mv "$temp_file.new" "$temp_file"
            fi
        else
            # 키는 있지만 값이 없는 경우 또는 키만 있는 경우
            if [ "$key_exists" = true ]; then
                echo -e "현재 ${key} 값이 비어 있습니다."
            fi
            
            # 새로운 값 입력 받기
            while true; do
                echo -n "$key 값을 입력하세요: "
                read -r value
                
                if validate_value "$key" "$value"; then
                    break
                fi
            done

            # 임시 파일에서 해당 키 라인을 새 값으로 교체
            if [ "$key_exists" = true ]; then
                awk -v key="$key" -v val="$value" '
                    $0 ~ "^"key"=" { print key"="val; next }
                    { print }
                ' "$temp_file" > "$temp_file.new" 2>/dev/null && mv "$temp_file.new" "$temp_file"
            fi
        fi
    done

    # 임시 파일을 compose-env 파일로 이동
    mv "$temp_file" "$compose_env_file" 2>/dev/null
    echo -e "\n${GREEN}compose-env 파일이 성공적으로 생성되었습니다.${NC}"
}

# 메인 실행 부분
echo -e "${YELLOW}compose-env 파일 설정 테스트를 시작합니다...${NC}"

# compose-env 파일 존재 확인
if [ ! -f "compose-env" ]; then
    echo -e "${RED}오류: compose-env 파일이 존재하지 않습니다.${NC}"
    exit 1
fi

# compose-env 파일 백업 (있는 경우)
if [ ! -f "compose-env.backup" ]; then
    cp compose-env compose-env.backup
    echo -e "${GREEN}compose-env 파일이 백업되었습니다.${NC}"
fi

while true; do
    # 환경 변수 입력 받기
    handle_env_input
    
    # 설정된 내용 확인
    echo -e "\n${YELLOW}현재 설정된 compose-env 파일 내용입니다:${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    cat compose-env
    echo -e "${BLUE}----------------------------------------${NC}"
    
    echo -e "\n${YELLOW}설정을 종료하시겠습니까? (y/n)${NC}"
    read -p "> " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}설정된 값으로 진행합니다.${NC}"
        break
    elif [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}환경 변수를 다시 설정합니다...${NC}"
        continue
    else
        echo -e "${RED}잘못된 입력입니다. y 또는 n을 입력해주세요.${NC}"
    fi
done 

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
        license_status=$?
        
        if [ $license_status -ne 0 ]; then
            echo -e "${RED}라이선스 추가 중 오류가 발생했습니다. 다시 시도하시겠습니까? (y/n)${NC}"
            read -r retry
            if [[ ! "$retry" =~ ^[Yy]$ ]]; then
                echo -e "${RED}설치를 중단합니다.${NC}"
                exit 1
            fi
            continue
        fi
        break
    elif [ -f "$license_file" ]; then
        echo -e "\n${YELLOW}라이선스 파일을 업로드합니다...${NC}"
        curl -XPOST 127.0.0.1:8050/license/upload -F "file=@$license_file"
        break
    else
        echo -e "${RED}파일을 찾을 수 없습니다. 다시 시도하세요.${NC}"
    fi
done

# 라이선스 추가 완료 확인
echo -e "\n${GREEN}라이선스 추가가 완료되었습니다.${NC}"
# read -p "계속하려면 Enter를 누르세요..."

echo -e "\n${YELLOW}tools를 종료합니다...${NC}"
docker-compose --env-file compose-env --profile tools down

echo -e "\n${YELLOW}QueryPie를 시작합니다...${NC}"
docker-compose --env-file compose-env --profile querypie up -d

echo -e "\n${GREEN}설치가 완료되었습니다. 로그를 확인합니다...${NC}"
docker logs -f querypie-app-1 