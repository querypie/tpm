#!/bin/bash

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

COUNT=1
OUTPUT_BASE_DIR=querypie_cs_report/$(date +%Y%m%d)/dotnet
OUTPUT_DIR=$OUTPUT_BASE_DIR
while [ -d "$OUTPUT_DIR" ]; do
    echo "${OUTPUT_DIR} is already exists... finding next"
    # 새 디렉토리 이름 생성
    OUTPUT_DIR="${OUTPUT_BASE_DIR}_${COUNT}"
    ((COUNT++))
done
echo "Making.. ${OUTPUT_DIR}"
mkdir -p $OUTPUT_DIR

# .NET stacks
print_banner ".NET stack dump"
echo "ps -T"
docker exec $QUERYPIE_NAME ps -T > $OUTPUT_DIR/ps

DOTNET_PS_OUTPUT=$(docker exec $QUERYPIE_NAME dotnet-dump ps)
echo "$DOTNET_PS_OUTPUT" | while read line; do
	PID=$(echo $line | awk '{print $1}')
	NAME=$(echo $line | awk '{print $2}')
	DUMPNAME=/app/dotnet_dump_$NAME

	mkdir -p $OUTPUT_DIR/$NAME

	docker exec $QUERYPIE_NAME dotnet-dump collect -n $NAME -o $DUMPNAME --type Mini
	docker exec $QUERYPIE_NAME dotnet-dump analyze $DUMPNAME -c 'threads' -c 'exit' > $OUTPUT_DIR/$NAME/threads
	tail -n +2 $OUTPUT_DIR/$NAME/threads | tr '*' ' ' | awk 'BEGIN {print "clrthreads"} {print "setthread " $1; print "clrstack"} END {print "exit"}' > $OUTPUT_DIR/$NAME/dstack_commands
	docker exec -i $QUERYPIE_NAME dotnet-dump analyze /app/dotnet_dump_$NAME < $OUTPUT_DIR/$NAME/dstack_commands > $OUTPUT_DIR/${NAME}.dstack
	docker exec $QUERYPIE_NAME rm $DUMPNAME
done

print_banner "Done..."
echo $OUTPUT_DIR
ls -al $OUTPUT_DIR
