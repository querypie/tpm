# Podman と Docker をサポートするユニバーサル実行環境

Version of compose.yml: 25.08.2
最終更新日: 2025年8月26日

QueryPie はコンテナ方式で配布されるアプリケーションであり、コンテナエンジンとして Docker と Podman をサポートしています。
このディレクトリのファイルは、Compose ツールを使用して QueryPie を実行および運用するための設定ファイルです。

Linux ディストリビューションによって、Podman と Docker Compose の組み合わせ、または Docker と Docker Compose の組み合わせを使用することをお勧めします。

## Podman をサポートする Linux ディストリビューション

以下の Linux ディストリビューションでは、Podman と Docker Compose の組み合わせを使用することをお勧めします：

- Red Hat Enterprise Linux 8+
- Rocky Linux 8+
- CentOS 8+

### 今後サポート予定の Linux ディストリビューション

以下の Linux ディストリビューションでは、Podman と Docker Compose の組み合わせを検証できていません。
Docker と Docker Compose の組み合わせを使用することをお勧めします：

- Amazon Linux 2, Amazon Linux 2023
- Ubuntu 22.04 LTS, 24.04 LTS

## Podman と Docker Compose のインストール

`setup.v2.sh` を使用すると、Linux サーバーに Podman と Docker Compose を自動的にインストールできます。
QueryPie をインストールするために setup.v2.sh を実行するだけで十分です。

## QueryPie を自動的にインストールして実行する

まず、サポートされている Linux ディストリビューションをインストールした Linux サーバーを準備します。

Linux サーバーのシェルで次のコマンドを実行します：
```shell
$ bash <(curl -s https://dl.querypie.com/setup.v2.sh)
```
または、次の方法を使用することもできます：
```shell
$ curl -s https://dl.querypie.com/setup.v2.sh -o setup.v2.sh
$ bash setup.v2.sh
```

`setup.v2.sh` を使用したインストールの詳細なガイドについては、次のドキュメントを参照してください：
[Installation Guide - setup.v2.sh (JA)](https://querypie.atlassian.net/wiki/spaces/QCP/pages/1177387032/Installation+Guide+-+setup.v2.sh+JA)


## Podman で QueryPie を手動で実行する

Podman は Docker と互換性のある方法で使用できます。ほとんどの Docker コマンドが Podman でサポートされています。

### MySQL と Redis の実行

1. `.env` ファイルの作成
   - `.env.template` をコピーして `.env` ファイルを作成し、必要な環境変数の値を設定します。
   - コマンド: `cp .env.template .env`、次に `vi .env`
   - 注意: `setup.v2.sh` スクリプトを使用すると、この手順は自動的に実行されます。
2. サービスの開始: `podman compose --profile=database up -d`
3. サービスの停止: `podman compose --profile=database down`

### QueryPie ツールの実行

1. ツールの開始: `podman compose --profile=tools up -d`
2. マイグレーションの実行: `podman compose --profile=tools exec tools /app/script/migrate.sh runall`
3. ツールの停止: `podman compose --profile=tools down`

### QueryPie アプリケーションの実行

1. アプリケーションの開始: `podman compose --profile=app up -d`
2. 正常な実行の確認: `podman compose --profile=app exec app readyz`
3. アプリケーションの停止: `podman compose --profile=app down`

## Docker で QueryPie を手動で実行する

### MySQL と Redis の実行

1. `.env` ファイルの作成
   - `.env.template` をコピーして `.env` ファイルを作成し、必要な環境変数の値を設定します。
   - コマンド: `cp .env.template .env`、次に `vi .env`
   - 注意: `setup.v2.sh` スクリプトを使用すると、この手順は自動的に実行されます。
2. サービスの開始: `docker compose --profile=database up -d`
3. サービスの停止: `docker compose --profile=database down`

### QueryPie ツールの実行

1. ツールの開始: `docker compose --profile=tools up -d`
2. マイグレーションの実行: `docker compose --profile=tools exec tools /app/script/migrate.sh runall`
3. ツールの停止: `docker compose --profile=tools down`

### QueryPie アプリケーションの実行

1. アプリケーションの開始: `docker compose --profile=app up -d`
2. 正常な実行の確認: `docker compose --profile=app exec app readyz`
3. アプリケーションの停止: `docker compose --profile=app down`

## 技術サポートのお問い合わせ

- Community Edition ユーザー：
  [QueryPie 公式 Discord チャンネル](https://discord.gg/Cu39M55gMk)に参加して、他のユーザーと質問や情報を共有することができます。
- Enterprise Edition ユーザー：
  技術サポートを担当するパートナーにお問い合わせください。