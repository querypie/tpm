#!/bin/bash
#
# Author: skipper
# Created: 2025-04-03
#
# 파일명: OneStepUpgrade.sh

# 에러 발생 시 스크립트 중단
set -e

# 함수: 사용법 출력
usage() {
    echo "사용법: $0 현재_버전 새_버전 [-y]"
    echo "예: $0 10.2.6 10.2.7"
    echo "예: $0 10.2.6 10.2.7 -y"
    exit 1
}

# 함수: 버전 형식 검증
validate_version() {
    local version=$1
    if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "오류: 버전은 major.minor.patch 형식이어야 합니다 (예: 10.2.7)"
        exit 1
    fi
}

# 함수: 사용자 확인 요청
confirm() {
    local message=$1
    if [ "$AUTO_YES" = "true" ]; then
        echo "${message} (자동 승인됨)"
        return 0
    fi
    read -p "${message} (y/Enter 계속, 다른 키 중단): " response
    if [[ ! "$response" =~ ^[yY]?$ ]]; then
        echo "작업이 사용자에 의해 중단되었습니다."
        exit 0
    fi
}

# 매개변수 확인
if [ $# -lt 2 ]; then
    usage
fi

# -y 옵션 확인
AUTO_YES="false"
if [ "$3" = "-y" ]; then
    AUTO_YES="true"
fi

CURRENT_VERSION=$1
NEW_VERSION=$2

# 버전 형식 검증
validate_version "$CURRENT_VERSION"
validate_version "$NEW_VERSION"

# 현재 버전 디렉토리 내 compose-env 파일 존재 여부 확인
CURRENT_COMPOSE_ENV="./querypie/${CURRENT_VERSION}/compose-env"
if [ ! -f "$CURRENT_COMPOSE_ENV" ]; then
    echo "오류: 현재 버전($CURRENT_VERSION)의 compose-env 파일을 찾을 수 없습니다."
    echo "경로: $CURRENT_COMPOSE_ENV"
    echo "현재 버전이 정확한지 확인하고 다시 시도하세요."
    exit 1
fi

echo "현재 버전: $CURRENT_VERSION (compose-env 파일 확인됨)"
echo "새 버전: $NEW_VERSION"

# 새 버전에서 필요한 환경변수 설정
MAJOR_MINOR=$(echo $NEW_VERSION | cut -d. -f1,2)
export DOWNLOAD_VERSION="${MAJOR_MINOR}.x"
export QP_VERSION="$NEW_VERSION"

echo "환경 변수가 설정되었습니다:"
echo "DOWNLOAD_VERSION=$DOWNLOAD_VERSION"
echo "QP_VERSION=$QP_VERSION"

# setup.sh 다운로드 및 실행
echo "setup.sh 다운로드 중..."
curl -L https://dl.querypie.com/releases/compose/setup.sh -o setup.sh
echo "setup.sh에 실행 권한 부여 중..."
chmod +x setup.sh
echo "setup.sh 실행 중..."
./setup.sh

# 새 버전 디렉토리로 이동
NEW_VERSION_DIR="./querypie/$NEW_VERSION"
if [ ! -d "$NEW_VERSION_DIR" ]; then
    echo "오류: 새 버전 디렉토리가 생성되지 않았습니다: $NEW_VERSION_DIR"
    exit 1
fi

echo "새 버전 디렉토리로 이동 중: $NEW_VERSION_DIR"
cd "$NEW_VERSION_DIR"

# 필요한 스크립트 다운로드
echo "merge-env.sh 다운로드 중..."
curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/merge-env/merge-env.sh -o merge-env.sh
chmod +x merge-env.sh

echo "scanner.sh 다운로드 중..."
curl -L https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/scanner/scanner.sh -o scanner.sh
chmod +x scanner.sh

# merge-env.sh 실행
echo "merge-env.sh 실행 중..."
./merge-env.sh "$CURRENT_VERSION" -y

# compose-env 내용 표시
# echo "compose-env 내용:"
# cat compose-env

# 사용자 확인
confirm "위 설정으로 계속 진행하시겠습니까?"

# docker instance 중지
echo "Docker 인스턴스 중지 중..."

# 실행 중인 인스턴스가 없어도 계속 진행
docker-compose --env-file compose-env --profile querypie down || {
    echo "실행 중인 Docker 인스턴스가 없거나 중지 중 오류가 발생했습니다. 계속 진행합니다."
}

# tools 프로필로 docker-compose 실행
echo "Docker tools 시작 중..."
docker-compose --env-file compose-env --profile tools up -d || {
    echo "Docker tools 시작 중 오류가 발생했습니다. 계속 진행합니다."
}

# 10초 대기
echo "10초 대기 중..."
sleep 10

# 마이그레이션 실행
echo "마이그레이션 실행 중..."

# 마이그레이션 실행 (최대 3번 시도, 5초 간격)
MAX_ATTEMPTS=3
ATTEMPT=1
MIGRATION_SUCCESS=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ "$MIGRATION_SUCCESS" = "false" ]; do
    echo "마이그레이션 시도 $ATTEMPT/$MAX_ATTEMPTS..."

    if docker exec -it querypie-tools-1 /app/script/migrate.sh runall; then
        MIGRATION_SUCCESS=true
        echo "마이그레이션이 성공적으로 완료되었습니다."
    else
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            echo "마이그레이션 실패. 5초 후 재시도합니다..."
            sleep 5
        else
            echo "마이그레이션 최대 시도 횟수에 도달했습니다. 계속 진행합니다."
        fi
    fi

    ATTEMPT=$((ATTEMPT+1))
done

# tools 중지
echo "QueryPie tools 서비스 중지 중..."
docker-compose --env-file compose-env --profile tools down || {
    echo "QueryPie tools 서비스 중지 중 오류가 발생했습니다. 계속 진행합니다."
}

# querypie 프로필로 docker-compose 실행
echo "QueryPie 서비스 시작 중..."
docker-compose --env-file compose-env --profile querypie up -d || {
    echo "QueryPie 서비스 시작 중 오류가 발생했습니다. 계속 진행합니다."
}

# 로그 확인
echo "애플리케이션 로그 확인 중... (종료하려면 Ctrl+C를 누르세요)"
docker logs -f querypie-app-1 || {
    echo "로그 확인 중 오류가 발생했습니다. 계속 진행합니다."
}

# 원래 위치로 돌아가기
echo "원래 위치로 돌아가는 중..."
cd ../..

echo "QueryPie $NEW_VERSION 으로의 업그레이드가 완료되었습니다!"
