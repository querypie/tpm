#!/bin/bash

# 입력 파라미터 개수 확인
if [ "$#" -ne 2 ]; then
    echo "사용법: $0 <web_domain> <host_domain>"
    echo "예시: $0 example.com api.example.com"
    exit 1
fi

# 파라미터를 변수에 저장
ORIGINAL_WEB_INPUT=$1 # 사용자의 원본 입력 저장

# 스키마 감지
if [[ "$ORIGINAL_WEB_INPUT" == https://* ]]; then
    WEB_SCHEME="https://"
elif [[ "$ORIGINAL_WEB_INPUT" == http://* ]]; then
    WEB_SCHEME="http://"
else
    # 스키마가 제공되지 않은 경우 https를 기본값으로 사용
    WEB_SCHEME="https://"
fi

# 입력된 첫번째 파라미터에서 스키마(http:// 또는 https://) 제거하여 WEB_DOMAIN 설정
WEB_DOMAIN=$(echo "$ORIGINAL_WEB_INPUT" | sed -E 's~^https?://~~')
HOST_DOMAIN=$2

# 색상 코드 정의 (가독성 향상)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}스크립트를 시작합니다. 입력된 도메인:${NC}"
echo "Web Domain: $WEB_DOMAIN"
echo "Host Domain: $HOST_DOMAIN"
echo "========================================"
echo

# 0. 프록시 설정 확인
echo -e "${BLUE}[0. 프록시 설정 확인]${NC}"
proxy_found=0
# 소문자 및 대문자 환경 변수 모두 확인
for proxy_var in http_proxy https_proxy ftp_proxy all_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY; do
    if [ -n "${!proxy_var}" ]; then
        echo "  ${YELLOW}${proxy_var}${NC}: ${!proxy_var}"
        proxy_found=1
    fi
done
# no_proxy 확인
for noproxy_var in no_proxy NO_PROXY; do
    if [ -n "${!noproxy_var}" ]; then
        echo "  ${YELLOW}${noproxy_var}${NC}: ${!noproxy_var}"
    fi
done

if [ $proxy_found -eq 0 ] && [ -z "$no_proxy" ] && [ -z "$NO_PROXY" ]; then
    echo -e "  => ${GREEN}설정된 프록시 관련 환경 변수가 없습니다.${NC}"
elif [ $proxy_found -eq 0 ]; then
     echo -e "  => ${GREEN}직접적인 프록시 설정은 없지만, no_proxy 설정은 존재합니다.${NC}"
else
     echo -e "  => ${YELLOW}하나 이상의 프록시 관련 환경 변수가 설정되어 있습니다.${NC}"
fi
echo "========================================"
echo


# 1. web_domain IP 목록 출력 (dig 사용)
echo -e "${BLUE}[1. $WEB_DOMAIN IP 주소 확인 (dig)]${NC}"
echo "명령어: dig +short $WEB_DOMAIN"
dig_output=$(dig +short "$WEB_DOMAIN")
if [ -n "$dig_output" ]; then
    echo -e "${GREEN}$dig_output${NC}"
else
    echo -e "  => ${RED}IP 주소를 찾을 수 없습니다.${NC}"
fi
echo "========================================"
echo


# 2. https://{web_domain}/version 내용 출력 (curl -v 사용)
VERSION_URL="${WEB_SCHEME}${WEB_DOMAIN}/version" # 감지된 스키마 사용
echo -e "${BLUE}[2. $VERSION_URL 내용 확인 (curl -v)]${NC}"
echo "명령어: curl -v $VERSION_URL"
# `-v` 옵션은 stderr로 출력되므로 그대로 실행
curl -v "$VERSION_URL"
echo # 결과와 구분하기 위한 줄바꿈
echo "========================================"
echo


# 3. DMG 다운로드 및 시간 측정 (파일 저장 안 함)
DMG_URL="${WEB_SCHEME}${WEB_DOMAIN}/agent/osx/arm64/QueryPieAgent.dmg" # 감지된 스키마 사용
echo -e "${BLUE}[3. $DMG_URL 다운로드 디버그 정보 및 시간 측정]${NC}"
echo "--- 다운로드 상세 정보 (curl -v) ---"
echo "명령어: curl -v -o /dev/null $DMG_URL"
# `-v` 옵션으로 상세 정보 출력, `-o /dev/null`로 파일 저장 안함
curl -v -o /dev/null "$DMG_URL"
echo # 결과와 구분하기 위한 줄바꿈
echo "--- 다운로드 시간 측정 ---"
echo "명령어: curl -s -o /dev/null -w '%{time_total} 초' $DMG_URL"
# `-s`로 진행률 숨김, `-w`로 총 시간(stdout)만 출력
download_time=$(curl -s -o /dev/null -w '%{time_total}' "$DMG_URL")
echo -e "다운로드 총 소요 시간: ${GREEN}${download_time} 초${NC}"
echo "========================================"
echo


# 4. host_domain IP 목록 출력 (dig 사용)
echo -e "${BLUE}[4. $HOST_DOMAIN IP 주소 확인 (dig)]${NC}"
echo "명령어: dig +short $HOST_DOMAIN"
dig_output_host=$(dig +short "$HOST_DOMAIN")
if [ -n "$dig_output_host" ]; then
    echo -e "${GREEN}$dig_output_host${NC}"
else
    echo -e "  => ${RED}IP 주소를 찾을 수 없습니다.${NC}"
fi
echo "========================================"
echo


# 5. host_domain:9000 TLS 인증서 정보 출력 (openssl 사용)
HOST_PORT="$HOST_DOMAIN:9000"
echo -e "${BLUE}[5. $HOST_PORT TLS 인증서 정보 확인 (openssl)]${NC}"
echo "명령어: echo | openssl s_client -connect $HOST_PORT -servername $HOST_DOMAIN -showcerts 2>/dev/null"
# `-servername` 옵션은 SNI(Server Name Indication)를 위해 필요합니다.
# `echo |`는 openssl이 stdin 입력을 기다리지 않도록 합니다.
# `2>/dev/null`은 연결 과정의 상세 오류(stderr)를 숨깁니다 (인증서 정보만 보려면).
cert_info=$(echo | openssl s_client -connect "$HOST_PORT" -servername "$HOST_DOMAIN" -showcerts 2>/dev/null)

if [ -n "$cert_info" ]; then
    echo -e "${GREEN}--- 서버 인증서 정보 ---${NC}"
    echo "$cert_info"
    # 예시: 인증서 만료일 파싱 (선택 사항)
    # expiry_date=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null)
    # if [ $? -eq 0 ]; then
    #     echo -e "${GREEN}인증서 만료일: $expiry_date${NC}"
    # fi
else
    echo -e "  => ${RED}$HOST_PORT 에 연결할 수 없거나 인증서 정보를 가져올 수 없습니다.${NC}"
    echo "  => ${YELLOW}상세 오류 확인을 위한 명령어:${NC}"
    echo "     echo | openssl s_client -connect $HOST_PORT -servername $HOST_DOMAIN -showcerts"
fi
echo "========================================"
echo

echo -e "${BLUE}스크립트 실행 완료.${NC}" 