# Universal Execution Environment Supporting Podman and Docker

Version of compose.yml: 25.08.2
Last updated: August 26, 2025

QueryPie is an application deployed in Container format, supporting both Docker and Podman as Container Engines.
The files in this directory are configuration files for running and operating QueryPie using Compose Tool.

Depending on your Linux distribution, it is recommended to use either a combination of Podman and Docker Compose, or Docker and Docker Compose.

## Linux Distributions Supporting Podman

For the following Linux distributions, it is recommended to use a combination of Podman and Docker Compose:

- Red Hat Enterprise Linux 8+
- Rocky Linux 8+
- CentOS 8+

### Linux Distributions Planned for Future Support

For the following Linux distributions, we have not yet verified the combination of Podman and Docker Compose.
It is recommended to use a combination of Docker and Docker Compose:

- Amazon Linux 2, Amazon Linux 2023
- Ubuntu 22.04 LTS, 24.04 LTS

## Installing Podman and Docker Compose

You can automatically install Podman and Docker Compose on your Linux server using `setup.v2.sh`.
Running setup.v2.sh to install QueryPie is sufficient.

## Automatically Install and Run QueryPie

First, prepare a Linux server with a supported Linux distribution installed.

Run the following command in the shell of your Linux server:
```shell
$ bash <(curl -s https://dl.querypie.com/setup.v2.sh)
```
Or you can use the following method:
```shell
$ curl -s https://dl.querypie.com/setup.v2.sh -o setup.v2.sh
$ bash setup.v2.sh
```

For detailed guidance on installation using `setup.v2.sh`, please refer to the following document:
[Installation Guide - setup.v2.sh (EN)](https://querypie.atlassian.net/wiki/spaces/QCP/pages/1176404033/Installation+Guide+-+setup.v2.sh+EN)


## Manually Running QueryPie with Podman

Podman can be used in a way that is compatible with Docker. Most Docker commands are supported in Podman.

### Running MySQL and Redis

1. Create a `.env` file
   - Copy `.env.template` to create a `.env` file and set the necessary environment variable values.
   - Commands: `cp .env.template .env`, then `vi .env`
   - Note: Using the `setup.v2.sh` script will perform this step automatically.
2. Start services: `podman compose --profile=database up -d`
3. Stop services: `podman compose --profile=database down`

### Running QueryPie Tools

1. Start tools: `podman compose --profile=tools up -d`
2. Run migration: `podman compose --profile=tools exec tools /app/script/migrate.sh runall`
3. Stop tools: `podman compose --profile=tools down`

### Running QueryPie Application

1. Start application: `podman compose --profile=app up -d`
2. Verify successful execution: `podman compose --profile=app exec app readyz`
3. Stop application: `podman compose --profile=app down`

## Manually Running QueryPie with Docker

### Running MySQL and Redis

1. Create a `.env` file
   - Copy `.env.template` to create a `.env` file and set the necessary environment variable values.
   - Commands: `cp .env.template .env`, then `vi .env`
   - Note: Using the `setup.v2.sh` script will perform this step automatically.
2. Start services: `docker compose --profile=database up -d`
3. Stop services: `docker compose --profile=database down`

### Running QueryPie Tools

1. Start tools: `docker compose --profile=tools up -d`
2. Run migration: `docker compose --profile=tools exec tools /app/script/migrate.sh runall`
3. Stop tools: `docker compose --profile=tools down`

### Running QueryPie Application

1. Start application: `docker compose --profile=app up -d`
2. Verify successful execution: `docker compose --profile=app exec app readyz`
3. Stop application: `docker compose --profile=app down`

## Technical Support

- Community Edition Users:
  Join our community on the [Official QueryPie Discord Channel](https://discord.gg/Cu39M55gMk) to ask questions and share insights with other users.
- Enterprise Edition Users:
  Please contact the partner responsible for technical support.
