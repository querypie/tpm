# Podman Compose, Docker Compose 모두를 위한 QueryPie 실행 환경

Podman, Podman Compose 를 지원하는 QueryPie 실행 환경을 제공합니다.
뿐만 아니라, Docker, Docker Compose 를 이용할 수도 있도록, 호환성을 유지하는 설정을 제공합니다.

## QueryPie 실행하기

### MySQL, Redis 를 실행하기

1. `.env` 파일을 작성하기
    - `.env.template`을 복사하여, `.env` 파일을 작성하고, 필요한 환경변수 값을 설정합니다.
    - `cp .env.template .env`, `vi .env`
2. 실행하기: `podman-compose --profile=database up -d`
3. 종료하기: `podman-compose --profile=database down`

### Tools 를 실행하기

1. 실행하기: `podman-compose --profile=tools up -d`
2. Migration 실행하기: `podman-compose --profile=tools exec tools /app/script/migrate.sh runall`
3. 종료하기: `podman-compose --profile=tools down`

### QueryPie 를 실행하기

1. 실행하기: `podman-compose --profile=app up -d`
2. 실행성공 확인하기: `podman-compose  --profile=app exec app readyz`
3. 종료하기: `podman-compose --profile=app down`

## Compose Yaml 의 변경사항

- Profile 설정을 사용하지 않고, database.yml, querypie.yml, tools.yml 등 Compose Yaml 을 세 개로 분리합니다.
  - Podman Compose 구버전은 Docker Compose 와 달리, Profile 설정을 지원하지 않습니다.
  - 검증 범위를 좁히고, 실행 명령을 간단하게 만들기 위해, Profile 을 사용하지 않도록 변경합니다.
- Container 이름을 지정할 때 사용하는 구분자를 `_`가 아닌 `-`를 사용하도록 설정을 추가합니다.
  - Podman Compose 는 기본으로 `_`를 구분자로 사용합니다. Docker Compose v2 와 호환되려면, `-`를 사용해야 합니다.
  - `x-podman: name_separator_compat: true` 라는 설정을 추가합니다.
  - Docker Compose v1 은 `_`를 구분자로, v2 는 `-`를 구분자로 사용합니다.
- MySQL 을 위한 `/var/lib/mysql` 데이터 디렉토리를 Host Filesystem 이 아닌 Container Volume 으로 제공합니다.
  - Podman 에서는 Host Filesystem 을 제공하는 경우, 해당 디렉토리의 Ownership 을 변경하지 못하여, 오류가 발생합니다.
- Docker Image 의 Registry 를 명시하여, `docker.io/` 라는 Registry 를 사용합니다.
  - Registry 가 명시되지 않으면, Podman Compose 에서 이미지를 내려받을 때, RHEL 의 Registry 를 사용할 것인지 질문을 받게 됩니다.

## Podman, Podman Compose 설치 방법

Podman, Podman Compose 가 배포본 패키지로 제공되는 리눅스 배포본이 다수입니다.
그러나, Amazon Linux 2023 에서는 Podman 설치 패키지가 제공되지 않습니다.

- Podman 설치 방법
  - `sudo dnf install podman`
- Podman Compose 설치 방법
  - `sudo dnf install -y python3.11 python3.11-pip python3.11-devel`
  - `python3.11 -m pip install --user podman-compose`
- 설치결과를 확인하기
  - `podman --version`
    - 4.9.4-rhel 또는 이후 버전인지 확인합니다.
  - `python3.11 --version`
  - `podman-compose --version`
    - 1.5.0 또는 이후 버전인지 확인합니다.

## SELinux 설정 변경

Red Hat Enterprise Linux 8.9 (Ootpa) 에서는 SELinux 가 활성화되어 있습니다.
Podman Compose 를 사용하기 위해서는 SELinux 설정을 변경해야 합니다.

- SELinux 설정을 변경하여 Container Volume Mounting 을 허용합니다.
  - `cd podman`
  - `sudo chcon -Rt container_file_t .`
  - `sudo chcon -Rt container_file_t ../log`
- Container Volume Mounting 대상의 SELinux 컨텍스트를 확인합니다.
  - `cd podman`
  - `ls -dlZ * ../log`
  - `unconfined_u:object_r:container_file_t:s0` 또는 `system_u:object_r:container_file_t:s0` 와 같은 컨텍스트가 표시되어야 합니다.
  - `user_home_t` 가 표시되는 경우, Container Volume Mounting 을 허용하지 않는 SELinux 설정입니다.
```shell
[ec2-user@ip-172-31-49-179 podman]$ ls -adlZ * ../log
drwxrwxrwx. 2 ec2-user ec2-user unconfined_u:object_r:container_file_t:s0     6 Jul 17 04:11 ../log
-rw-rw-r--. 1 ec2-user ec2-user unconfined_u:object_r:container_file_t:s0  3501 Jul 17 04:14 README.md
drwxrwxr-x. 2 ec2-user ec2-user unconfined_u:object_r:container_file_t:s0    22 Jul 13 09:52 certs
-rw-rw-r--. 1 ec2-user ec2-user unconfined_u:object_r:container_file_t:s0  1278 Jul 17 03:57 database-compose.yml
-rw-rw-r--. 1 ec2-user ec2-user unconfined_u:object_r:container_file_t:s0 10368 Jul 13 10:48 docker-compose.yml
drwxr-xr-x. 2 ec2-user ec2-user system_u:object_r:container_file_t:s0        22 Jul 13 06:35 mysql_init
drwxrwxr-x. 2 ec2-user ec2-user unconfined_u:object_r:container_file_t:s0    38 Jul 13 09:52 nginx.d
-rw-rw-r--. 1 ec2-user ec2-user unconfined_u:object_r:container_file_t:s0  2800 Jul 17 04:23 querypie-compose.yml
-rw-rw-r--. 1 ec2-user ec2-user unconfined_u:object_r:container_file_t:s0     4 Jul 13 06:35 skip_command_config.json
-rw-rw-r--. 1 ec2-user ec2-user unconfined_u:object_r:container_file_t:s0   670 Jul 13 06:35 skip_command_config.json.example
-rw-rw-r--. 1 ec2-user ec2-user unconfined_u:object_r:container_file_t:s0  1850 Jul 13 11:43 tools-compose.yml
[ec2-user@ip-172-31-49-179 podman]$ 
```

## 테스트 환경

- Red Hat Enterprise Linux release 8.9 (Ootpa) with Podman, Podman Compose
  - podman-compose version 1.5.0
  - podman version 4.9.4-rhel
- Amazon Linux 2023 with Docker, Docker Compose
  - Docker version 25.0.8, build 0bab007
  - Docker Compose version v2.13.0
