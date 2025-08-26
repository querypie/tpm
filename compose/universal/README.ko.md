# Podman, Docker 를 지원하는 Universal 실행 환경

Version of compose.yml: 25.08.2
최종 업데이트: 2025년 8월 26일

QueryPie 는 Container 방식으로 배포되는 애플리케이션이며, Container Engine 으로 Docker 와 Podman 을 지원합니다.
이 디렉토리의 파일은 QueryPie 를 Compose Tool 을 이용해 실행하고 운영하기 위한 설정파일입니다.

리눅스 배포본에 따라, Podman 과 Docker Compose 의 조합, 또는 Docker 와 Docker Compose 의 조합으로 사용하는 것을 권장합니다.

## Podman 을 지원하는 리눅스 배포본

다음의 리눅스 배포본에서는, Podman 과 Docker Compose 의 조합으로 사용하는 것을 권장합니다.

- Red Hat Enterprise Linux 8+
- Rocky Linux 8+
- CentOS 8+

### 추후 지원 예정인 리눅스 배포본

다음의 리눅스 배포본에서는, Podman 과 Docker Compose 의 조합을 검증하지 못하였습니다.
Docker 와 Docker Compose 의 조합을 사용하는 것을 권장합니다.

- Amazon Linux 2, Amazon Linux 2023
- Ubuntu 22.04 LTS, 24.04 LTS

## Podman 과 Docker Compose 설치하기

`setup.v2.sh` 를 이용하면, 리눅스 서버에 Podman, Docker Compose 를 자동으로 설치할 수 있습니다.
QueryPie 를 설치하기 위한 setup.v2.sh 를 실행하는 것으로 충분합니다.

## QueryPie 를 자동으로 설치하고 실행하기

먼저, 지원하는 리눅스 배포본을 설치한 리눅스 서버를 준비합니다.

리눅스 서버의 shell 에서 다음 명령을 실행합니다.
```shell
$ bash <(curl -s https://dl.querypie.com/setup.v2.sh)
```
또는 다음의 방법을 사용하여도 됩니다.
```shell
$ curl -s https://dl.querypie.com/setup.v2.sh -o setup.v2.sh
$ bash setup.v2.sh
```

`setup.v2.sh`를 이용한 설치 방법에 대한 상세한 가이드는 다음 문서를 참조하세요:
[Installation Guide - setup.v2.sh (KO)](https://querypie.atlassian.net/wiki/spaces/QCP/pages/1177321474/Installation+Guide+-+setup.v2.sh+KO)


## Podman 으로 QueryPie 수작업 실행하기

Podman 은 Docker 와 호환되는 방식으로 사용할 수 있습니다. 대부분의 Docker 명령이 Podman 에서 지원됩니다.

### MySQL 및 Redis 실행하기

1. `.env` 파일 생성하기
   - `.env.template`를 복사하여 `.env` 파일을 생성하고 필요한 환경 변수 값을 설정합니다.
   - 명령어: `cp .env.template .env`, 그리고 `vi .env`
   - 참고: `setup.v2.sh` 스크립트를 사용하면 이 단계가 자동으로 수행됩니다.
2. 서비스 시작: `podman compose --profile=database up -d`
3. 서비스 중지: `podman compose --profile=database down`

### QueryPie Tools 실행하기

1. Tools 시작: `podman compose --profile=tools up -d`
2. Migration 실행: `podman compose --profile=tools exec tools /app/script/migrate.sh runall`
3. Tools 중지: `podman compose --profile=tools down`

### QueryPie Application 실행하기

1. Application 시작: `podman compose --profile=app up -d`
2. 성공적인 실행 확인: `podman compose --profile=app exec app readyz`
3. Application 중지: `podman compose --profile=app down`

## Docker 로 QueryPie 수작업 실행하기

### MySQL 및 Redis 실행하기

1. `.env` 파일 생성하기
    - `.env.template`를 복사하여 `.env` 파일을 생성하고 필요한 환경 변수 값을 설정합니다.
    - 명령어: `cp .env.template .env`, 그리고 `vi .env`
    - 참고: `setup.v2.sh` 스크립트를 사용하면 이 단계가 자동으로 수행됩니다.
2. 서비스 시작: `docker compose --profile=database up -d`
3. 서비스 중지: `docker compose --profile=database down`

### QueryPie Tools 실행하기

1. Tools 시작: `docker compose --profile=tools up -d`
2. Migration 실행: `docker compose --profile=tools exec tools /app/script/migrate.sh runall`
3. Tools 중지: `docker compose --profile=tools down`

### QueryPie Application 실행하기

1. Application 시작: `docker compose --profile=app up -d`
2. 성공적인 실행 확인: `docker compose --profile=app exec app readyz`
3. Application 중지: `docker compose --profile=app down`

## 기술지원 문의

- Community Edition 이용자:
    [QueryPie 공식 디스코드 채널](https://discord.gg/Cu39M55gMk)에서 자유롭게 사용자 간 Q&A와 정보 공유를 할 수 있으니 많은 참여 부탁드립니다.
- Enterprise Edition 이용자:
    기술지원을 담당하는 파트너에게 문의 부탁드립니다.
