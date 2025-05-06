#!/bin/bash

# Terraform 출력에서 EC2 인스턴스 ID 추출
INSTANCE_ID=$(terraform show | grep -Eo '\bi-[0-9a-fA-F]{8,17}\b' | sort | uniq)

# 테라폼 출력에서 EC2 인스턴스 IP 추출
INSTANCE_IP=$(terraform output -json instance_public_ip | jq -r '.')

# 테라폼 출력에서 AWS 키 페어 파일 이름 추출
AWS_KEY_PAIR_FILENAME=$(terraform output -json aws_key_pair_filename | jq -r '.')

# 인스턴스 ID가 없는 경우 스크립트 종료
if [ -z "$INSTANCE_ID" ]; then
    echo "No EC2 instance ID found in Terraform output."
    exit 1
fi

# 추출된 인스턴스 ID와 IP 출력
echo "Found EC2 instance ID: $INSTANCE_ID"
echo "Found EC2 instance IP: $INSTANCE_IP"

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
    echo "Connecting to EC2 instance..."
    echo "ssh -i $AWS_KEY_PAIR_FILENAME ec2-user@$INSTANCE_IP"
    chmod 400 $AWS_KEY_PAIR_FILENAME
    ssh -i $AWS_KEY_PAIR_FILENAME ec2-user@$INSTANCE_IP
    ;;
*)
    echo "Invalid action. Please enter 'start', 'stop' or 'connect'."
    exit 1
    ;;
esac

# 작업 완료 메시지
echo "Action '$ACTION' completed for instance: $INSTANCE_ID"
