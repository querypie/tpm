# QueryPie Execution Environment for both Podman Compose and Docker Compose

Version of compose.yml: 25.07.2
Last updated: July 30, 2025

This repository provides a QueryPie execution environment that supports both Podman and Podman Compose.
It also includes compatibility settings that allow Docker and Docker Compose to be used as alternatives.
The following guide provides instructions on how to run QueryPie using Podman and Podman Compose.

## Automatically Install and Run QueryPie

Please refer to the "Installation Methods for Podman and Podman Compose" section to install podman and podman-compose first.

Run the following command in the shell of your Linux server. Note that you must not omit the `--universal` option.
```shell
$ bash <(curl -s https://dl.querypie.com/setup.v2.sh) --universal
```
Or you can use the following method:
```shell
$ curl -s https://dl.querypie.com/setup.v2.sh -o setup.v2.sh
$ bash setup.v2.sh --universal
```

For detailed guidance on installation using `setup.v2.sh`, please refer to the following document:
[Installation Guide - setup.v2.sh (EN)](https://querypie.atlassian.net/wiki/spaces/QCP/pages/1176404033/Installation+Guide+-+setup.v2.sh+EN)


## Manually Running QueryPie

### Running MySQL and Redis

1. Create a `.env` file
  - Copy `.env.template` to create a `.env` file and set the necessary environment variable values.
  - Commands: `cp .env.template .env`, then `vi .env`
  - Note: Using the `setup.v2.sh` script will perform this step automatically.
2. Start services: `podman-compose --profile=database up -d`
3. Stop services: `podman-compose --profile=database down`

### Running Tools

1. Start tools: `podman-compose --profile=tools up -d`
2. Run migration: `podman-compose --profile=tools exec tools /app/script/migrate.sh runall`
3. Stop tools: `podman-compose --profile=tools down`

### Running QueryPie Application

1. Start application: `podman-compose --profile=app up -d`
2. Verify successful execution: `podman-compose --profile=app exec app readyz`
3. Stop application: `podman-compose --profile=app down`

## Changes to Compose YAML

The following changes have been made to ensure compatibility between Podman Compose and Docker Compose:

- Added settings to use `-` instead of `_` as the separator when specifying container names.
  - Podman Compose uses `_` as the default separator. To be compatible with Docker Compose v2, `-` should be used.
  - Added the setting `x-podman: name_separator_compat: true`.
  - Note: Docker Compose v1 uses `_` as a separator, while v2 uses `-`.
- Specified the Docker Image Registry to use the `docker.io/` Registry.
  - If the Registry is not specified, Podman Compose will prompt you to choose whether to use the RHEL Registry when downloading images.

## Installation Methods for Podman and Podman Compose

Many Linux distributions provide Podman and Podman Compose as distribution packages.
However, Amazon Linux 2023 does not include Podman installation packages by default.

### Installation on RHEL8

- Podman Installation:
  - `sudo dnf install podman`
- Podman Compose Installation:
  - `sudo dnf install -y python3.11 python3.11-pip python3.11-devel`
  - `python3.11 -m pip install --user podman-compose`
- Verifying Installation:
  - `podman --version`
    - Ensure that it is version 4.9.4-rhel or later.
  - `python3.11 --version`
  - `podman-compose --version`
    - Ensure that it is version 1.5.0 or later.

## SELinux Configuration Changes

SELinux is enabled by default on Red Hat Enterprise Linux 8.9 (Ootpa).
To use Podman Compose successfully, you need to modify the SELinux settings as follows:

- Change SELinux settings to allow Container Volume Mounting:
  - `cd podman`
  - `sudo chcon -Rt container_file_t .`
  - `sudo chcon -Rt container_file_t ../log`
- Verify the SELinux context of the Container Volume Mounting target:
  - `cd podman`
  - `ls -dlZ * ../log`
  - You should see contexts like `unconfined_u:object_r:container_file_t:s0` or `system_u:object_r:container_file_t:s0`.
  - If `user_home_t` is displayed, it indicates a SELinux setting that does not permit Container Volume Mounting.

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

## Test Environment

This configuration has been tested on the following environments:

- Red Hat Enterprise Linux release 8.9 (Ootpa) with Podman and Podman Compose:
  - podman-compose version 1.5.0
  - podman version 4.9.4-rhel
- Amazon Linux 2023 with Docker and Docker Compose:
  - Docker version 25.0.8, build 0bab007
  - Docker Compose version v2.13.0
