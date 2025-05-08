#!/bin/bash

# 첫 번째 파라미터로 IP 주소 받기
target_ip=$1

# 두 번째 파라미터로 포트 번호 받기 (선택 사항)
custom_port=$2

# 파라미터 유효성 검사
if [ -z "$target_ip" ]; then
  echo "오류: IP 주소를 첫 번째 파라미터로 입력해주세요."
  echo "사용 예: $0 <IP 주소> [포트 번호 (기본값: 80)]"
  exit 1
fi

# 포트 번호 설정
port=9000 # 기본 포트
if [ -n "$custom_port" ]; then # 두 번째 파라미터가 제공되었으면
  # 입력된 포트가 숫자인지 간단히 확인 (더 엄격한 검증이 필요할 수 있음)
  if ! [[ "$custom_port" =~ ^[0-9]+$ ]]; then
    echo "오류: 포트 번호는 숫자여야 합니다."
    echo "사용 예: $0 <IP 주소> [포트 번호 (기본값: 80)]"
    exit 1
  fi
  if [ "$custom_port" -lt 1 ] || [ "$custom_port" -gt 65535 ]; then
    echo "오류: 포트 번호는 1에서 65535 사이여야 합니다."
    exit 1
  fi
  port=$custom_port
fi

# 시도 횟수
num_attempts=20
# 각 시도 사이의 대기 시간 (초)
delay_seconds=1
# curl 타임아웃 (초)
timeout_seconds=3

echo -e "\n${target_ip}:${port}에 대해 ${num_attempts}회 접속 테스트를 시작합니다 (매 시도 간 ${delay_seconds}초 대기)...\n"

for i in $(seq 1 $num_attempts)
do
  echo "시도 ${i}/${num_attempts}:"

  # curl을 사용하여 연결 시도 및 연결 시간 측정
  # -s: silent 모드 (진행률 표시 안 함)
  # -o /dev/null: 다운로드 내용을 버림 (연결만 테스트)
  # --connect-timeout: 연결 타임아웃 설정
  # -w '%{time_connect}': 연결 완료까지 걸린 시간을 출력 형식으로 지정
  # ${target_ip}:${port} : 테스트할 주소와 포트
  connection_time=$(curl -s -o /dev/null --connect-timeout $timeout_seconds -w "%{time_connect}" "${target_ip}:${port}")

  # curl 명령어의 종료 코드 확인 (0이면 성공)
  if [[ $? -eq 52 || $? -eq 0 ]]; then
    echo "  성공! 접속 시간: ${connection_time} 초"
  else
    echo "  실패! (종료 코드: $?) (IP: ${target_ip}, 포트: ${port})"
  fi

  # 마지막 시도가 아니면 대기
  if [ $i -lt $num_attempts ]; then
    sleep $delay_seconds
  fi
  echo "----------------------------------------"
done

echo -e "\n모든 접속 테스트가 완료되었습니다."
