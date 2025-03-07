# Introduction

QueryPie 업그레이드할 때
compose-env의 빈 값을 채워주는 스크립트 (from: 이전버전, to: 신규버전)

# 파일명
merge-env.sh

# 사용법
신규버전 디렉토리로 이동
merge-env.sh 다운로드 (다운로드 URL)
chmod +x merge-env.sh

# 예제
./merge-env.sh 10.1.9 --dry-run
./merge-env.sh 10.1.9
./merge-env.sh undo