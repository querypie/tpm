# Universal Execution Environment Supporting Podman and Docker

Version of compose.yml: 26.02.1
Last updated: February 24, 2026

QueryPie ACP is an application deployed in Container format, supporting both Docker and Podman as Container Engines.
The files in this directory are configuration files for running and operating QueryPie ACP using Compose Tool.

Depending on your Linux distribution, it is recommended to use either a combination of Podman and Docker Compose, or Docker and Docker Compose.

## Docker/Podman Support by Linux Distribution

The recommended Container Engine varies depending on the Linux distribution.
For details, refer to [Linux Distribution and Docker/Podman Support Status](https://docs.querypie.com/en/installation/prerequisites/linux-distribution-and-docker-podman-support-status).

| Distribution | Docker | Podman |
|--------------|--------|--------|
| Amazon Linux 2 | ✅ Supported | ❌ Not Supported |
| Amazon Linux 2023 | ✅ Supported | ❌ Not Supported |
| RHEL 8 | ✅ Available | ✅ Recommended |
| RHEL 9 | ✅ Available | ✅ Recommended |
| RHEL 10 | ❌ Not Supported | ✅ Recommended |
| Rocky Linux 9 | ✅ Available | ✅ Recommended |
| Ubuntu 22.04 LTS | ✅ Supported | ❌ Not Supported |
| Ubuntu 24.04 LTS | ✅ Supported | ✅ Supported |

## Installing Docker or Podman

You can automatically install Docker or Podman, along with Docker Compose, on your Linux server using `setup.v2.sh`.
Running setup.v2.sh to install QueryPie ACP is sufficient.

## Automatically Install and Run QueryPie ACP

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
[Installation Guide - setup.v2.sh](https://docs.querypie.com/en/installation/installation/installation-guide-setupv2sh)


## Manually Running QueryPie ACP with Podman

Podman can be used in a way that is compatible with Docker. Most Docker commands are supported in Podman.

### Running MySQL and Redis

1. Create a `.env` file
   - Copy `.env.template` to create a `.env` file and set the necessary environment variable values.
   - Commands: `cp .env.template .env`, then `vi .env`
   - Note: Using the `setup.v2.sh` script will perform this step automatically.
2. Start services: `podman compose --profile=database up -d`
3. Stop services: `podman compose --profile=database down`

### Running QueryPie ACP Tools

1. Start tools: `podman compose --profile=tools up -d`
2. Run migration: `podman compose --profile=tools exec tools /app/script/migrate.sh runall`
3. Stop tools: `podman compose --profile=tools down`

### Running QueryPie ACP Application

1. Start application: `podman compose --profile=app up -d`
2. Verify successful execution: `podman compose --profile=app exec app readyz`
3. Stop application: `podman compose --profile=app down`

## Manually Running QueryPie ACP with Docker

### Running MySQL and Redis

1. Create a `.env` file
   - Copy `.env.template` to create a `.env` file and set the necessary environment variable values.
   - Commands: `cp .env.template .env`, then `vi .env`
   - Note: Using the `setup.v2.sh` script will perform this step automatically.
2. Start services: `docker compose --profile=database up -d`
3. Stop services: `docker compose --profile=database down`

### Running QueryPie ACP Tools

1. Start tools: `docker compose --profile=tools up -d`
2. Run migration: `docker compose --profile=tools exec tools /app/script/migrate.sh runall`
3. Stop tools: `docker compose --profile=tools down`

### Running QueryPie ACP Application

1. Start application: `docker compose --profile=app up -d`
2. Verify successful execution: `docker compose --profile=app exec app readyz`
3. Stop application: `docker compose --profile=app down`

## Technical Support

Please refer to the [Technical Support](https://docs.querypie.com/en/support) page.
