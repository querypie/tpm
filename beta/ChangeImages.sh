#!/bin/bash
#
# Author: skipper
# Created: 2025-04-03

# 에러 발생 시 스크립트 종료
set -e

# 색상 코드 정의
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

# 버전 및 옵션 인자 확인
if [ $# -lt 1 ]; then
    echo -e "${RED}버전을 인자로 전달해주세요.${NC}"
    echo "사용법: $0 <버전> [--with-tools]"
    echo "  버전: major.minor.patch 형식 (예: 10.2.7)"
    echo "  --with-tools: querypie-tools 이미지도 함께 삭제합니다."
    exit 1
fi

VERSION=$1

# 버전 형식 검증
if ! validate_version "$VERSION"; then
    exit 1
fi

DELETE_TOOLS=false

# 옵션 확인
if [ $# -eq 2 ] && [ "$2" == "--with-tools" ]; then
    DELETE_TOOLS=true
    echo -e "${YELLOW}querypie-tools 이미지도 함께 삭제합니다.${NC}"
fi

# 현재 디렉토리 저장
ORIGINAL_DIR=$(pwd)

# 대상 디렉토리 경로 설정
TARGET_DIR="./querypie/$VERSION"

# 대상 디렉토리 존재 여부 확인
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}오류: $TARGET_DIR 디렉토리가 존재하지 않습니다.${NC}"
    exit 1
fi

# compose-env 파일 존재 여부 확인
if [ ! -f "$TARGET_DIR/compose-env" ]; then
    echo -e "${RED}오류: $TARGET_DIR/compose-env 파일이 존재하지 않습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}필요한 디렉토리와 파일이 모두 존재합니다. 계속 진행합니다.${NC}"

# 대상 디렉토리로 이동
cd "$TARGET_DIR"

echo -e "${YELLOW}QueryPie 서비스를 내리는 중...${NC}"
docker-compose --env-file compose-env --profile querypie down

echo -e "${YELLOW}버전 ${VERSION}의 이미지를 확인하는 중...${NC}"

# querypie 이미지 확인 및 삭제
if docker images | grep -q "harbor.chequer.io/querypie/querypie.*${VERSION}"; then
    echo -e "${GREEN}harbor.chequer.io/querypie/querypie:${VERSION} 이미지를 삭제합니다.${NC}"
    docker rmi harbor.chequer.io/querypie/querypie:${VERSION} || true
else
    echo -e "${RED}harbor.chequer.io/querypie/querypie:${VERSION} 이미지가 존재하지 않습니다.${NC}"
fi

# querypie-tools 이미지 확인 및 삭제 (옵션이 활성화된 경우에만)
if [ "$DELETE_TOOLS" = true ]; then
    if docker images | grep -q "harbor.chequer.io/querypie/querypie-tools.*${VERSION}"; then
        echo -e "${GREEN}harbor.chequer.io/querypie/querypie-tools:${VERSION} 이미지를 삭제합니다.${NC}"
        docker rmi harbor.chequer.io/querypie/querypie-tools:${VERSION} || true
    else
        echo -e "${RED}harbor.chequer.io/querypie/querypie-tools:${VERSION} 이미지가 존재하지 않습니다.${NC}"
    fi
else
    echo -e "${YELLOW}querypie-tools 이미지 삭제를 건너뜁니다.${NC}"
fi

echo -e "${YELLOW}QueryPie 서비스를 다시 시작하는 중...${NC}"
docker-compose --env-file compose-env --profile querypie up -d

echo -e "${GREEN}서비스가 시작되었습니다. 로그를 확인합니다...${NC}"
docker logs -f querypie-app-1 &
LOGS_PID=$!

# 로그 프로세스가 시작되기를 기다림
sleep 2

# Ctrl+C 시그널 핸들러 설정
trap 'kill $LOGS_PID 2>/dev/null || true; cd "$ORIGINAL_DIR"; exit' INT TERM

# 로그 프로세스가 종료될 때까지 대기
wait $LOGS_PID || true

# 원래 디렉토리로 복귀
cd "$ORIGINAL_DIR"

echo -e "${GREEN}모든 작업이 완료되었습니다.${NC}"
