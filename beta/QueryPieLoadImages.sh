#!/bin/bash

# 스크립트 실행 중 오류 발생 시 즉시 종료 (-e), 정의되지 않은 변수 사용 시 오류 발생 (-u)
set -eu

# --- 설정 ---
EXPECTED_PLATFORM_FILENAME_PART="linux-amd64"
# --- 설정 끝 ---

# 1. 파라미터 확인 및 할당 (버전 필수, 앱 이름 선택)
if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "오류: 잘못된 파라미터 개수입니다." >&2
  echo "사용법: $0 <major.minor.patch> [app_name]" >&2
  echo "  - app_name: 'querypie' 또는 'tools' (선택 사항, 없으면 둘 다 처리)" >&2
  echo "예시: $0 10.2.1" >&2
  echo "예시: $0 10.2.1 querypie" >&2
  exit 1
fi
VERSION="$1"
# 두 번째 파라미터가 없으면 기본값 'all' 사용
APP_NAME="${2:-all}"

# 2. 버전 형식 검증 (major.minor.patch)
VERSION_REGEX="^[0-9]+\.[0-9]+\.[0-9]+$"
if [[ ! "$VERSION" =~ $VERSION_REGEX ]]; then
  echo "오류: 잘못된 버전 형식입니다. 'major.minor.patch' 형식을 사용해야 합니다 (예: 10.2.1)." >&2
  exit 1
fi

# 3. 앱 이름 파라미터 검증 (제공된 경우)
if [[ "$APP_NAME" != "all" && "$APP_NAME" != "querypie" && "$APP_NAME" != "tools" ]]; then
  echo "오류: 잘못된 앱 이름입니다. 'querypie' 또는 'tools'를 사용하거나 생략하세요." >&2
  exit 1
fi
echo "요청 처리: Version=${VERSION}, App=${APP_NAME}"
echo "---"

# 4. 로드할 .tar 파일 이름 정의 (항상 둘 다 정의)
TAR_FILENAME="querypie-${VERSION}-${EXPECTED_PLATFORM_FILENAME_PART}.tar"
TOOLS_TAR_FILENAME="querypie-tools-${VERSION}-${EXPECTED_PLATFORM_FILENAME_PART}.tar"

# 5. Docker 명령어 확인 및 데몬 확인
# ... (이전 스크립트와 동일) ...
if ! command -v docker &> /dev/null; then echo "오류: 'docker' 명령어를 찾을 수 없습니다..."; exit 1; fi
if ! docker info > /dev/null 2>&1; then echo "오류: Docker 데몬에 연결할 수 없습니다..."; exit 1; fi
echo "Docker 환경 확인 완료."
echo "---"

# 6. 처리 대상 플래그 설정 및 파일 존재 여부 확인
LOAD_MAIN=false
LOAD_TOOLS=false
TOTAL_STEPS=0

echo "이미지 파일 존재 여부 확인 중..."
if [[ "$APP_NAME" == "all" || "$APP_NAME" == "querypie" ]]; then
  if [ ! -f "$TAR_FILENAME" ]; then
    echo "오류: 메인 이미지 파일 '${TAR_FILENAME}'을(를) 현재 디렉토리에서 찾을 수 없습니다." >&2
    exit 1
  fi
  echo " - 메인 이미지 파일 확인됨: ${TAR_FILENAME}"
  LOAD_MAIN=true
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi
if [[ "$APP_NAME" == "all" || "$APP_NAME" == "tools" ]]; then
  if [ ! -f "$TOOLS_TAR_FILENAME" ]; then
    echo "오류: Tools 이미지 파일 '${TOOLS_TAR_FILENAME}'을(를) 현재 디렉토리에서 찾을 수 없습니다." >&2
    exit 1
  fi
  echo " - Tools 이미지 파일 확인됨: ${TOOLS_TAR_FILENAME}"
  LOAD_TOOLS=true
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi
echo "파일 확인 완료."
echo "---"

CURRENT_STEP=0

# 7. 이미지 로드 (조건부)
if [[ "$LOAD_MAIN" == true ]]; then
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo "[${CURRENT_STEP}/${TOTAL_STEPS}] 메인 이미지 로딩 시작: ${TAR_FILENAME}"
  if ! docker load -i "$TAR_FILENAME"; then echo "오류: 메인 이미지 로딩 실패 (${TAR_FILENAME})."; exit 1; fi
  echo "메인 이미지 로딩 성공."
  echo "---"
fi
if [[ "$LOAD_TOOLS" == true ]]; then
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo "[${CURRENT_STEP}/${TOTAL_STEPS}] Tools 이미지 로딩 시작: ${TOOLS_TAR_FILENAME}"
  if ! docker load -i "$TOOLS_TAR_FILENAME"; then echo "오류: Tools 이미지 로딩 실패 (${TOOLS_TAR_FILENAME})."; exit 1; fi
  echo "Tools 이미지 로딩 성공."
  echo "---"
fi

# 8. 최종 성공 메시지
echo "========================================"
echo "성공!"
echo "요청한 이미지 파일들을 로컬 Docker에 성공적으로 로드했습니다:"
if [[ "$LOAD_MAIN" == true ]]; then
  echo " - 메인 이미지 파일: ${TAR_FILENAME}"
fi
if [[ "$LOAD_TOOLS" == true ]]; then
  echo " - Tools 이미지 파일: ${TOOLS_TAR_FILENAME}"
fi
echo ""
echo "'docker images' 명령어를 사용하여 로드된 이미지를 확인할 수 있습니다."
echo "========================================"

exit 0

