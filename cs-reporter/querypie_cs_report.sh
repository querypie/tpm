#!/bin/bash

TOP_SECONDS=5

print_banner() {
    local text="$1"
    local width=${2:-80}  # 기본 너비 50
    local char=${3:-"#"}  # 기본 테두리 문자 #
    
    # 상단 테두리
    printf "\n%${width}s\n" | tr ' ' "$char"
    
    # 배너 텍스트 중앙 정렬
    local text_length=${#text}
    local padding=$(( (width - text_length - 2) / 2 - 1))
    
    printf "%s " "$char"
    printf "%${padding}s%s%${padding}s" "" "$text" ""
    # 너비가 홀수일 경우 한쪽에 공백 추가
    if [ $(( (width - text_length - 2) % 2 )) -ne 0 ]; then
        printf " "
    fi
    printf " %s\n" "$char"
    
    # 하단 테두리
    printf "%${width}s\n\n" | tr ' ' "$char"
}

QUERYPIE_NAME=$1
if [ -z "$QUERYPIE_NAME" ]; then
	QUERYPIE_NAME=$(docker ps --filter "name=^querypie" --format "{{.Names}}")
else
	QUERYPIE_NAME_EXISTS=$(docker ps --filter name="^$QUERYPIE_NAME$" --format "{{.Names}}")
	if [ -z "$QUERYPIE_NAME_EXISTS" ]; then
		echo "querypie container($QUERYPIE_NAME) 를 찾을 수 없습니다. $0 <querypie container name> 으로 실행해주세요요."
		exit -1
	fi
fi

if [ -z "$QUERYPIE_NAME" ]; then
	echo "querypie container 를 찾을 수 없습니다. $0 <querypie container name> 으로 실행해주세요요."
	exit -1
fi

print_banner "QueryPie Env Checker (name: $QUERYPIE_NAME)"

COUNT=1
OUTPUT_BASE_DIR=querypie_cs_report/$(date +%Y%m%d)/system
OUTPUT_DIR=$OUTPUT_BASE_DIR
while [ -d "$OUTPUT_DIR" ]; do
    echo "${OUTPUT_DIR} is already exists... finding next"
    # 새 디렉토리 이름 생성
    OUTPUT_DIR="${OUTPUT_BASE_DIR}_${COUNT}"
    ((COUNT++))
done
echo "Making.. ${OUTPUT_DIR}"
mkdir -p $OUTPUT_DIR

# CPU 개수 출력
print_banner "Check Cpu info => $OUTPUT_DIR/cpu_info"
cat /proc/cpuinfo > $OUTPUT_DIR/cpu_info
echo -n "Processors: "
fgrep 'processor' $OUTPUT_DIR/cpu_info | wc -l

# Memory 상태 확인
print_banner "Check memory => $OUTPUT_DIR/free"
free -m | tee $OUTPUT_DIR/free

# Network 상태 확인
print_banner "Check networking => $OUTPUT_DIR/netstat"
/sbin/ifconfig > $OUTPUT_DIR/ifconfig
netstat -an > $OUTPUT_DIR/netstat
echo -n "Listening... : "
cat $OUTPUT_DIR/netstat | grep LISTEN | egrep ^tcp | fgrep LISTEN | wc -l

docker exec querypie /sbin/ifconfig > $OUTPUT_DIR/docker_ifconfig
docker exec querypie netstat -an > $OUTPUT_DIR/docker_netstat
echo -n "Docker Listening... : "
cat $OUTPUT_DIR/docker_netstat | grep LISTEN | egrep ^tcp | fgrep LISTEN | wc -l

# top 으로 현재 상태 확인
print_banner "Top current system => $OUTPUT_DIR/top_current_system"
top -b -c -d 1 -n 1 | head -n 20
top -b -c -d 1 -n $TOP_SECONDS > $OUTPUT_DIR/top_current_system

# docker 상태 확인 (10초)
print_banner "Check docker info => $OUTPUT_DIR/docker_inspect, docker_stats"
docker inspect $QUERYPIE_NAME > $OUTPUT_DIR/docker_inspect
for i in $( seq 1 10 ); do
	docker stats --no-stream
done | tee $OUTPUT_DIR/docker_stats

# sar 결과
print_banner "sar -A => $OUTPUT_DIR/sar"
sar -A > $OUTPUT_DIR/sar

# docker 내에서 top (60 초)
print_banner "Top&Ps $QUERYPIE_NAME (inside docker, $TOP_SECONDS seconds)"
docker exec $QUERYPIE_NAME top -b -d 1 -n 1 
docker exec $QUERYPIE_NAME top -b -d 1 -n $TOP_SECONDS > $OUTPUT_DIR/top_${TOP_SECONDS}
echo "top (with all threads)"
docker exec $QUERYPIE_NAME top -b -d 1 -n $TOP_SECONDS -H > $OUTPUT_DIR/top_${TOP_SECONDS}_all_threads
echo "top (with memory)"
docker exec $QUERYPIE_NAME top -b -d 1 -n 1 -m
docker exec $QUERYPIE_NAME top -b -d 1 -n $TOP_SECONDS -m > $OUTPUT_DIR/top_${TOP_SECONDS}_memory
echo "ps -T"
docker exec $QUERYPIE_NAME ps -T > $OUTPUT_DIR/ps


print_banner "Jstack for all JVM"
# docker 내에서 API jstack 덤프
JPS_OUTPUT=$(docker exec $QUERYPIE_NAME jps | fgrep -v Jps)
echo "$JPS_OUTPUT" | while read line; do
	PID=$(echo $line | awk '{print $1}')
	NAME=$(echo $line | awk '{print $2}')
	echo "jstack -l $PID => $OUTPUT_DIR/${NAME}_${PID}.jstack"
	docker exec $QUERYPIE_NAME jstack -l $PID > $OUTPUT_DIR/${NAME}_${PID}.jstack
done

echo "Sleep 10 secons..."
sleep 10

echo "jstack (after 10 seconds)"
echo "$JPS_OUTPUT" | while read line; do
	PID=$(echo $line | awk '{print $1}')
	NAME=$(echo $line | awk '{print $2}')

	echo "jstack -l $PID => $OUTPUT_DIR/${NAME}_${PID}.jstack"
	docker exec $QUERYPIE_NAME jstack -l $PID > $OUTPUT_DIR/${NAME}_${PID}_AFTER10.jstack
done

print_banner "Done..."
echo $OUTPUT_DIR
ls -al $OUTPUT_DIR
