# Introduction

- QueryPie 업그레이드할 때 compose-env의 빈 값을 채워주는 스크립트 (from: 이전버전, to: 신규버전)


# 파일명
- merge-env.sh


# 사전 준비
- 신규버전 디렉토리로 이동
- merge-env.sh 다운로드 
```
curl -l https://raw.githubusercontent.com/querypie/tpm/refs/heads/main/merge-env/merge-env.sh -o merge-env.sh
```
- chmod +x merge-env.sh


# 사용법
- 파일 변경 없이 결과만 출력
    - ```./merge-env.sh 이전버전 --dry-run```
- 신규버전 compose-env 파일내 빈 값을 이전버전 내용으로 채워서 저장 (기존 파일 backup 으로 저장)
  - ```./merge-env.sh 이전버전```
- 초기 compose-env 로 원복
  - ```./merge-env.sh undo```                     


# 예제
- ./merge-env.sh 10.1.9 --dry-run
- ./merge-env.sh 10.1.9
- ./merge-env.sh undo