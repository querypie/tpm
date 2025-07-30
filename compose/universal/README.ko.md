# Podman Compose 및 Docker Compose를 위한 QueryPie 실행 환경

Version of compose.yml: 25.07.2
최종 업데이트: 2025년 7월 30일

이 저장소는 Podman 및 Podman Compose를 지원하는 QueryPie 실행 환경을 제공합니다.
또한 Docker 및 Docker Compose를 대안으로 사용할 수 있는 호환성 설정도 포함되어 있습니다.
다음 가이드는 Podman 및 Podman Compose를 사용하여 QueryPie를 실행하는 방법에 대한 지침을 제공합니다.

## QueryPie 를 자동으로 설치하고 실행하기

"Podman 및 Podman Compose 설치 방법" 섹션을 참고하여, podman, podman-compose 를 먼저 설치하여 주세요.

리눅스 서버의 shell 에서 다음 명령을 실행합니다. `--universal` 옵션을 빠뜨리지 않아야 한다는 것에 주의하여 주세요.
```shell
$ bash <(curl -s https://dl.querypie.com/setup.v2.sh) --universal
```
또는 다음의 방법을 사용하여도 됩니다.
```shell
$ curl -s https://dl.querypie.com/setup.v2.sh -o setup.v2.sh
$ bash setup.v2.sh --universal
```

`setup.v2.sh`를 이용한 설치 방법에 대한 상세한 가이드는 다음 문서를 참조하세요:
[Installation Guide - setup.v2.sh (KO)](https://querypie.atlassian.net/wiki/spaces/QCP/pages/1177321474/Installation+Guide+-+setup.v2.sh+KO)


## QueryPie 수작업 실행하기

### MySQL 및 Redis 실행하기

1. `.env` 파일 생성하기
   - `.env.template`를 복사하여 `.env` 파일을 생성하고 필요한 환경 변수 값을 설정합니다.
   - 명령어: `cp .env.template .env`, 그리고 `vi .env`
   - 참고: `setup.v2.sh` 스크립트를 사용하면 이 단계가 자동으로 수행됩니다.
2. 서비스 시작: `podman-compose --profile=database up -d`
3. 서비스 중지: `podman-compose --profile=database down`

### 도구 실행하기

1. 도구 시작: `podman-compose --profile=tools up -d`
2. 마이그레이션 실행: `podman-compose --profile=tools exec tools /app/script/migrate.sh runall`
3. 도구 중지: `podman-compose --profile=tools down`

### QueryPie 애플리케이션 실행하기

1. 애플리케이션 시작: `podman-compose --profile=app up -d`
2. 성공적인 실행 확인: `podman-compose --profile=app exec app readyz`
3. 애플리케이션 중지: `podman-compose --profile=app down`

## Compose YAML 변경 사항

Podman Compose와 Docker Compose 간의 호환성을 보장하기 위해 다음과 같은 변경 사항이 적용되었습니다:

- 컨테이너 이름을 지정할 때 구분자로 `_` 대신 `-`를 사용하도록 설정을 추가했습니다.
  - Podman Compose는 기본 구분자로 `_`를 사용합니다. Docker Compose v2와 호환되려면 `-`를 사용해야 합니다.
  - `x-podman: name_separator_compat: true` 설정을 추가했습니다.
  - 참고: Docker Compose v1은 구분자로 `_`를 사용하고, v2는 `-`를 사용합니다.
- Docker 이미지 레지스트리를 `docker.io/` 레지스트리를 사용하도록 지정했습니다.
  - 레지스트리가 지정되지 않으면, 이미지를 다운로드할 때 Podman Compose가 RHEL 레지스트리를 사용할지 여부를 선택하라는 메시지를 표시합니다.

## Podman 및 Podman Compose 설치 방법

많은 Linux 배포판에서 Podman 및 Podman Compose를 배포 패키지로 제공합니다.
그러나 Amazon Linux 2023은 기본적으로 Podman 설치 패키지를 포함하지 않습니다.

### RHEL8 에서 설치하는 방법

- Podman 설치:
  - `sudo dnf install podman`
- Podman Compose 설치:
  - `sudo dnf install -y python3.11 python3.11-pip python3.11-devel`
  - `python3.11 -m pip install --user podman-compose`
- 설치 확인:
  - `podman --version`
    - 버전이 4.9.4-rhel 이상인지 확인하세요.
  - `python3.11 --version`
  - `podman-compose --version`
    - 버전이 1.5.0 이상인지 확인하세요.

## SELinux 구성 변경

SELinux는 Red Hat Enterprise Linux 8.9 (Ootpa)에서 기본적으로 활성화되어 있습니다.
Podman Compose를 성공적으로 사용하려면 다음과 같이 SELinux 설정을 수정해야 합니다:

- 컨테이너 볼륨 마운팅을 허용하도록 SELinux 설정 변경:
  - `cd podman`
  - `sudo chcon -Rt container_file_t .`
  - `sudo chcon -Rt container_file_t ../log`
- 컨테이너 볼륨 마운팅 대상의 SELinux 컨텍스트 확인:
  - `cd podman`
  - `ls -dlZ * ../log`
  - `unconfined_u:object_r:container_file_t:s0` 또는 `system_u:object_r:container_file_t:s0`와 같은 컨텍스트가 표시되어야 합니다.
  - `user_home_t`가 표시되면 컨테이너 볼륨 마운팅을 허용하지 않는 SELinux 설정을 나타냅니다.

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

이 구성은 다음 환경에서 테스트되었습니다:

- Red Hat Enterprise Linux release 8.9 (Ootpa)와 Podman 및 Podman Compose:
  - podman-compose 버전 1.5.0
  - podman 버전 4.9.4-rhel
- Amazon Linux 2023과 Docker 및 Docker Compose:
  - Docker 버전 25.0.8, 빌드 0bab007
  - Docker Compose 버전 v2.13.0