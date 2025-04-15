#!/bin/bash

# QueryPie Simple Installer
# Created: 2025-04-05

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 서버 IP 주소 가져오기 함수
get_server_ip() {
    # eth0, ens, enp 인터페이스 중 활성화된 인터페이스의 IP 주소를 찾음
    local ip=$(ip addr show | grep -E 'inet.*(eth|ens|enp)' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n1)
    
    # 위 방법으로 IP를 찾지 못한 경우, 기본 네트워크 인터페이스에서 IP를 찾음
    if [ -z "$ip" ]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    
    # 여전히 IP를 찾지 못한 경우 기본값 반환
    if [ -z "$ip" ]; then
        ip="192.168.1.100"
    fi
    
    echo "$ip"
}

# 버전 형식 검증 함수
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Version must be in major.minor.patch format (e.g., 10.2.7)${NC}"
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
        echo -e "Current ${key} value: $current_value"
        read -p "Press Enter to keep the current value. Enter a new value to change: " new_value
        if [ -z "$new_value" ]; then
            new_value=$current_value
        fi
    else
        read -p "Enter ${key} value: " new_value
    fi
    
    echo "$new_value"
}

# 사용법 체크
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "  version: major.minor.patch format (e.g., 10.2.7)"
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

echo -e "${GREEN}Starting QueryPie installation. Version: $QP_VERSION${NC}"

# setup.sh 다운로드 및 실행
echo -e "\n${YELLOW}Downloading installation script...${NC}"
curl -L https://dl.querypie.com/releases/compose/setup.sh -o setup.sh
chmod +x setup.sh

echo -e "\n${YELLOW}Running installation script...${NC}"
./setup.sh

# 도커 실행 권한 확인
if ! check_docker_permission; then
    echo -e "\n${YELLOW}Docker execution permission is required. Adding permission...${NC}"
    sudo usermod -aG docker $USER
    echo -e "${GREEN}Docker execution permission has been added.${NC}"
    echo -e "${YELLOW}You need to log out and log back in for the permission to take effect.${NC}"
    echo -e "${YELLOW}After logging in, please run the following command again:${NC}"
    echo -e "${GREEN}$0 $NEW_VERSION${NC}"
    echo -e "${RED}Script is terminating. Please log out and run again.${NC}"
    exit 1
fi

# 실행 위치로 이동
TARGET_DIR="./querypie/$NEW_VERSION"
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: Directory $TARGET_DIR does not exist.${NC}"
    exit 1
fi

cd "$TARGET_DIR"

if [ ! -f "compose-env" ]; then
    echo -e "${RED}Error: compose-env file does not exist.${NC}"
    exit 1
fi

# 하버 레지스트리 로그인
echo -e "\n${YELLOW}Logging in to Harbor registry...${NC}"
while true; do
    # 직접 로그인 명령어 실행
    docker login harbor.chequer.io
    login_status=$?
    
    if [ $login_status -eq 0 ]; then
        # 로그인 성공 확인
        if docker login harbor.chequer.io 2>&1 | grep -q "Authenticating with existing credentials"; then
            echo -e "${GREEN}Login successful${NC}"
            break
        fi
    fi
    
    echo -e "${RED}Login failed. Would you like to try again? (y/n)${NC}"
    read -r retry
    if [[ ! "$retry" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Installation aborted.${NC}"
        exit 1
    fi
done

# compose-env 파일 백업
if [ ! -f "compose-env.backup" ]; then
    cp compose-env compose-env.backup
    echo -e "${GREEN}compose-env file has been backed up.${NC}"
else
    echo -e "${YELLOW}compose-env.backup file already exists.${NC}"
fi

# 환경 변수 설정
echo -e "\n${YELLOW}Setting environment variables...${NC}"

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
        echo -e "${RED}Error: compose-env file not found.${NC}"
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
        echo -e "${RED}Error: Only alphanumeric characters and punctuation are allowed.${NC}"
        return 1
    fi

    # REDIS_PASSWORD 빈 값 확인
    if [ "$key" = "REDIS_PASSWORD" ]; then
        if [ -z "$value" ]; then
            echo -e "${YELLOW}Warning: REDIS_PASSWORD is empty. This is not recommended for security reasons.${NC}"
            while true; do
                read -p "Do you want to continue with an empty value? (y/n): " confirm
                case $confirm in
                    [Yy]* )
                        return 0;;
                    [Nn]* )
                        return 1;;
                    * )
                        echo "Please enter y or n.";;
                esac
            done
        fi
        return 0
    fi

    # REDIS_CONNECTION_MODE 검증
    if [ "$key" = "REDIS_CONNECTION_MODE" ]; then
        if [ "$value" != "STANDALONE" ] && [ "$value" != "CLUSTER" ]; then
            echo -e "${RED}Error: REDIS_CONNECTION_MODE must be either STANDALONE or CLUSTER.${NC}"
            return 1
        fi
        return 0
    fi

    # REDIS_NODES 검증
    if [ "$key" = "REDIS_NODES" ]; then
        # 마지막 쉼표 제거
        value=$(echo "$value" | sed 's/,$//')
        
        # host:port 형식 또는 쉼표로 연결된 host:port 형식 검증
        IFS=',' read -ra nodes <<< "$value"
        for node in "${nodes[@]}"; do
            if ! [[ "$node" =~ ^[^:]+:[0-9]+$ ]]; then
                echo -e "${RED}Error: REDIS_NODES must be in host:port format (e.g., localhost:6379) or comma-separated host:port format (e.g., localhost:6379,redis2:6379).${NC}"
                return 1
            fi
        done
        return 0
    fi

    # AGENT_SECRET 검증
    if [ "$key" = "AGENT_SECRET" ]; then
        if [ ${#value} -ne 32 ]; then
            echo -e "${RED}Error: AGENT_SECRET must be exactly 32 characters. Current length: ${#value}${NC}"
            return 1
        fi
        return 0
    fi

    # QUERYPIE_WEB_URL 검증
    if [ "$key" = "QUERYPIE_WEB_URL" ]; then
        if [[ ! "$value" =~ ^https?:// ]]; then
            echo -e "${RED}Error: QUERYPIE_WEB_URL must start with http:// or https://.${NC}"
            return 1
        fi
        return 0
    fi

    # 나머지 키들은 빈 값 체크
    if [ -z "$value" ]; then
        echo -e "${RED}Error: $key is a required value. Please enter a value.${NC}"
        return 1
    fi

    return 0
}

# 환경 변수 입력 처리 함수
handle_env_input() {
    local compose_env_file="compose-env"
    local temp_file="compose-env.temp"
    local server_ip=$(get_server_ip)
    
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
            echo -e "${YELLOW}QUERYPIE_WEB_URL must start with http:// or https://.${NC}"
        fi
        
        # 키가 있고 값이 있는 경우
        if [ "$key_exists" = true ] && [ -n "$existing_value" ]; then
            echo -e "Current ${key} value ${RED}[${existing_value}]${NC}"
            echo -n "Enter a new value (press Enter to keep current value): "
            read -r value

            # Enter를 누른 경우 기존 값 유지
            if [ -z "$value" ]; then
                value="$existing_value"
            else
                # 새로운 값이 입력된 경우 검증
                while ! validate_value "$key" "$value"; do
                    echo -n "Enter a new value: "
                    read -r value
                    # Enter를 누른 경우 기존 값으로 복귀
                    if [ -z "$value" ]; then
                        value="$existing_value"
                        break
                    fi
                done
            fi

            # REDIS_NODES의 경우 마지막 쉼표 제거
            if [ "$key" = "REDIS_NODES" ]; then
                value=$(echo "$value" | sed 's/,$//')
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
                case "$key" in
                    "DB_HOST")
                        echo -e "Current ${key} value is empty. (ex: ${server_ip})"
                        ;;
                    "REDIS_HOST")
                        echo -e "Current ${key} value is empty. (ex: ${server_ip})"
                        ;;
                    "REDIS_NODES")
                        echo -e "Current ${key} value is empty. (ex: ${server_ip}:6379)"
                        ;;
                    "REDIS_CONNECTION_MODE")
                        echo -e "Current ${key} value is empty. (ex: STANDALONE or CLUSTER)"
                        ;;
                    "QUERYPIE_WEB_URL")
                        echo -e "Current ${key} value is empty. (ex: http://${server_ip})"
                        ;;
                    "AGENT_SECRET")
                        echo -e "Current ${key} value is empty. (ex: openssl rand -hex 16)"
                        ;;
                    *)
                        echo -e "Current ${key} value is empty."
                        ;;
                esac
            fi
            
            # 새로운 값 입력 받기
            while true; do
                echo -n "Enter ${key} value: "
                read -r value
                
                if validate_value "$key" "$value"; then
                    break
                fi
            done

            # REDIS_NODES의 경우 마지막 쉼표 제거
            if [ "$key" = "REDIS_NODES" ]; then
                value=$(echo "$value" | sed 's/,$//')
            fi

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
    echo -e "\n${GREEN}compose-env file has been successfully created.${NC}"
}

# 메인 실행 부분
echo -e "${YELLOW}Starting compose-env file configuration test...${NC}"

# compose-env 파일 존재 확인
if [ ! -f "compose-env" ]; then
    echo -e "${RED}Error: compose-env file does not exist.${NC}"
    exit 1
fi

# compose-env 파일 백업 (있는 경우)
if [ ! -f "compose-env.backup" ]; then
    cp compose-env compose-env.backup
    echo -e "${GREEN}compose-env file has been backed up.${NC}"
fi

while true; do
    # 환경 변수 입력 받기
    handle_env_input
    
    # 설정된 내용 확인
    echo -e "\n${YELLOW}Current compose-env file content:${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    cat compose-env
    echo -e "${BLUE}----------------------------------------${NC}"
    
    echo -e "\n${YELLOW}Do you want to finish the configuration? (y/n)${NC}"
    read -p "> " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Proceeding with the configured values.${NC}"
        break
    elif [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Reconfiguring environment variables...${NC}"
        continue
    else
        echo -e "${RED}Invalid input. Please enter y or n.${NC}"
    fi
done 

echo -e "\n${YELLOW}Starting database...${NC}"
docker-compose --env-file compose-env --profile database up -d

echo -e "\n${YELLOW}Waiting 10 seconds...${NC}"
sleep 10

echo -e "\n${YELLOW}Starting tools...${NC}"
docker-compose --env-file compose-env --profile tools up -d

echo -e "\n${YELLOW}Waiting 10 seconds...${NC}"
sleep 10

echo -e "\n${YELLOW}Running migration...${NC}"
docker exec -it querypie-tools-1 /app/script/migrate.sh runall

# 라이선스 파일 처리
echo -e "\n${YELLOW}Checking license files...${NC}"

# 스크립트 실행 위치의 .crt 파일 찾기
current_dir=$(pwd)
cd ../..
crt_files=(*.crt)

if [ -e "${crt_files[0]}" ]; then
    echo -e "${GREEN}Found license files:${NC}"
    for file in *.crt; do
        echo "- $file"
        cp "$file" "$current_dir/"
    done
    cd "$current_dir"
    echo -e "\n${YELLOW}License files have been copied to the current directory.${NC}"
else
    cd "$current_dir"
    echo -e "${RED}No license files (.crt) found in the parent directory.${NC}"
fi

# 현재 디렉토리의 .crt 파일 목록 표시
echo -e "\n${YELLOW}License files in the current directory:${NC}"
if ls *.crt >/dev/null 2>&1; then
    for file in *.crt; do
        echo "- $file"
    done
else
    echo -e "${RED}No license files in the current directory.${NC}"
fi

# 라이선스 추가 방식 선택
echo -e "\n${YELLOW}Adding license...${NC}"
while true; do
    echo "Enter license filename:"
    read -p "> " license_file

    if [ "$license_file" = "querypie" ]; then
        echo -e "\n${YELLOW}Adding internal QueryPie license...${NC}"
        docker exec -it querypie-tools-1 /app/script/license.sh add
        license_status=$?
        
        if [ $license_status -ne 0 ]; then
            echo -e "${RED}Error occurred while adding license. Would you like to try again? (y/n)${NC}"
            read -r retry
            if [[ ! "$retry" =~ ^[Yy]$ ]]; then
                echo -e "${RED}Installation aborted.${NC}"
                exit 1
            fi
            continue
        fi
        break
    elif [ -f "$license_file" ]; then
        echo -e "\n${YELLOW}Uploading license file...${NC}"
        curl -XPOST 127.0.0.1:8050/license/upload -F "file=@$license_file"
        break
    else
        echo -e "${RED}File not found. Please try again.${NC}"
    fi
done

# 라이선스 추가 완료 확인
echo -e "\n${GREEN}License addition completed.${NC}"
# read -p "Press Enter to continue..."

echo -e "\n${YELLOW}Stopping tools...${NC}"
docker-compose --env-file compose-env --profile tools down

echo -e "\n${YELLOW}Starting QueryPie...${NC}"
docker-compose --env-file compose-env --profile querypie up -d

echo -e "\n${GREEN}Installation completed. Checking logs...${NC}"
docker logs -f querypie-app-1 