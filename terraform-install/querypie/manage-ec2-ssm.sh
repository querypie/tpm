#!/bin/bash

# Terraform 출력에서 EC2 인스턴스 ID 추출
INSTANCE_ID=$(terraform show | grep -Eo '\bi-[0-9a-fA-F]{8,17}\b' | sort | uniq)

# 인스턴스 ID가 없는 경우 스크립트 종료
if [ -z "$INSTANCE_ID" ]; then
    echo "No EC2 instance ID found in Terraform output."
    exit 1
fi

# 추출된 인스턴스 ID 출력
echo "Found EC2 instance ID: $INSTANCE_ID"

# 사용자에게 인스턴스를 중지할지 시작할지 묻기
if [ $# -eq 0 ]; then
    echo "No action specified. Usage: $0 {start|stop|connect}"
    exit 1
fi

ACTION=$1

# 인스턴스 시작, 중지 또는 연결
case $ACTION in
start)
    echo "Starting instances..."
    aws ec2 start-instances --instance-ids $INSTANCE_ID
    ;;
stop)
    echo "Stopping instances..."
    aws ec2 stop-instances --instance-ids $INSTANCE_ID
    ;;
connect)
    echo "Connecting to EC2 instance using SSM..."
    aws ssm start-session --target $INSTANCE_ID
    ;;
*)
    echo "Invalid action. Please enter 'start', 'stop' or 'connect'."
    exit 1
    ;;
esac

# 작업 완료 메시지
echo "Action '$ACTION' completed for instance: $INSTANCE_ID"
