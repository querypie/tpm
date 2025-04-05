#!/bin/bash

# 스크립트 실행 중 오류 발생 시 즉시 종료 (-e), 정의되지 않은 변수 사용 시 오류 발생 (-u)
set -eu

# --- 설정 ---
HARBOR_REGISTRY="harbor.chequer.io"
IMAGE_REPO="querypie/querypie"
TOOLS_IMAGE_REPO="querypie/querypie-tools"
TARGET_PLATFORM="linux/amd64" # 다운로드할 플랫폼 지정
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

# 4. 이미지 전체 경로 및 출력 파일 이름 정의 (항상 둘 다 정의)
FULL_IMAGE_NAME="${HARBOR_REGISTRY}/${IMAGE_REPO}:${VERSION}"
OUTPUT_FILENAME="querypie-${VERSION}-${TARGET_PLATFORM//\//-}.tar"

FULL_TOOLS_IMAGE_NAME="${HARBOR_REGISTRY}/${TOOLS_IMAGE_REPO}:${VERSION}"
OUTPUT_TOOLS_FILENAME="querypie-tools-${VERSION}-${TARGET_PLATFORM//\//-}.tar"

# 5. Docker 명령어 확인 및 데몬 확인
# ... (이전 스크립트와 동일) ...
if ! command -v docker &> /dev/null; then echo "오류: 'docker' 명령어를 찾을 수 없습니다..."; exit 1; fi
if ! docker info > /dev/null 2>&1; then echo "오류: Docker 데몬에 연결할 수 없습니다..."; exit 1; fi
echo "Docker 환경 확인 완료."
echo "---"

# 6. 처리 대상 플래그 설정
PULL_SAVE_MAIN=false
PULL_SAVE_TOOLS=false
TOTAL_STEPS=0

if [[ "$APP_NAME" == "all" || "$APP_NAME" == "querypie" ]]; then
  PULL_SAVE_MAIN=true
  TOTAL_STEPS=$((TOTAL_STEPS + 2)) # Pull + Save
fi
if [[ "$APP_NAME" == "all" || "$APP_NAME" == "tools" ]]; then
  PULL_SAVE_TOOLS=true
  TOTAL_STEPS=$((TOTAL_STEPS + 2)) # Pull + Save
fi

CURRENT_STEP=0

# 7. 이미지 풀링 (조건부)
if [[ "$PULL_SAVE_MAIN" == true ]]; then
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo "[${CURRENT_STEP}/${TOTAL_STEPS}] 메인 이미지 풀링 시작 (${TARGET_PLATFORM}): ${FULL_IMAGE_NAME}"
  if ! docker pull --platform "${TARGET_PLATFORM}" "${FULL_IMAGE_NAME}"; then echo "오류: 메인 이미지 풀링 실패..."; exit 1; fi
  echo "메인 이미지 풀링 성공."
  echo "---"
fi
if [[ "$PULL_SAVE_TOOLS" == true ]]; then
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo "[${CURRENT_STEP}/${TOTAL_STEPS}] Tools 이미지 풀링 시작 (${TARGET_PLATFORM}): ${FULL_TOOLS_IMAGE_NAME}"
  if ! docker pull --platform "${TARGET_PLATFORM}" "${FULL_TOOLS_IMAGE_NAME}"; then echo "오류: Tools 이미지 풀링 실패..."; exit 1; fi
  echo "Tools 이미지 풀링 성공."
  echo "---"
fi

# 8. 이미지 저장 (조건부)
if [[ "$PULL_SAVE_MAIN" == true ]]; then
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo "[${CURRENT_STEP}/${TOTAL_STEPS}] 메인 이미지 저장 중: ${OUTPUT_FILENAME}"
  if ! docker save -o "${OUTPUT_FILENAME}" "${FULL_IMAGE_NAME}"; then echo "오류: 메인 이미지 저장 실패..."; exit 1; fi
  echo "메인 이미지 저장 성공."
  echo "---"
fi
if [[ "$PULL_SAVE_TOOLS" == true ]]; then
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo "[${CURRENT_STEP}/${TOTAL_STEPS}] Tools 이미지 저장 중: ${OUTPUT_TOOLS_FILENAME}"
  if ! docker save -o "${OUTPUT_TOOLS_FILENAME}" "${FULL_TOOLS_IMAGE_NAME}"; then echo "오류: Tools 이미지 저장 실패..."; exit 1; fi
  echo "Tools 이미지 저장 성공."
  echo "---"
fi

# 9. 최종 성공 메시지
echo "========================================"
echo "성공!"
echo "요청한 이미지를 성공적으로 다운로드하고 저장했습니다."
if [[ "$PULL_SAVE_MAIN" == true ]]; then
  echo " - 메인 이미지: ${OUTPUT_FILENAME}"
fi
if [[ "$PULL_SAVE_TOOLS" == true ]]; then
  echo " - Tools 이미지: ${OUTPUT_TOOLS_FILENAME}"
fi
echo "========================================"

exit 0
