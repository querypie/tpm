# Podman と Docker をサポートするユニバーサル実行環境

Version of compose.yml: 26.02.1
最終更新日: 2026年2月24日

QueryPie ACP はコンテナ方式で配布されるアプリケーションであり、コンテナエンジンとして Docker と Podman をサポートしています。
このディレクトリのファイルは、Compose ツールを使用して QueryPie ACP を実行および運用するための設定ファイルです。

Linux ディストリビューションによって、Podman と Docker Compose の組み合わせ、または Docker と Docker Compose の組み合わせを使用することをお勧めします。

## Linux ディストリビューション別 Docker/Podman サポート状況

推奨されるコンテナエンジンは Linux ディストリビューションによって異なります。
詳細は [Linux ディストリビューション別 Docker/Podman サポート状況](https://docs.querypie.com/ja/installation/prerequisites/linux-distribution-and-docker-podman-support-status) をご参照ください。

| ディストリビューション | Docker | Podman |
|------------------------|--------|--------|
| Amazon Linux 2 | ✅ サポート | ❌ 非サポート |
| Amazon Linux 2023 | ✅ サポート | ❌ 非サポート |
| RHEL 8 | ✅ 利用可能 | ✅ 推奨 |
| RHEL 9 | ✅ 利用可能 | ✅ 推奨 |
| RHEL 10 | ❌ 非サポート | ✅ 推奨 |
| Rocky Linux 9 | ✅ 利用可能 | ✅ 推奨 |
| Ubuntu 22.04 LTS | ✅ サポート | ❌ 非サポート |
| Ubuntu 24.04 LTS | ✅ サポート | ✅ サポート |

## Docker または Podman のインストール

`setup.v2.sh` を使用すると、Linux サーバーに Docker または Podman、および Docker Compose を自動的にインストールできます。
QueryPie ACP をインストールするために setup.v2.sh を実行するだけで十分です。

## QueryPie ACP を自動的にインストールして実行する

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
[Installation Guide - setup.v2.sh](https://docs.querypie.com/ja/installation/installation/installation-guide-setupv2sh)


## Podman で QueryPie ACP を手動で実行する

Podman は Docker と互換性のある方法で使用できます。ほとんどの Docker コマンドが Podman でサポートされています。

### MySQL と Redis の実行

1. `.env` ファイルの作成
   - `.env.template` をコピーして `.env` ファイルを作成し、必要な環境変数の値を設定します。
   - コマンド: `cp .env.template .env`、次に `vi .env`
   - 注意: `setup.v2.sh` スクリプトを使用すると、この手順は自動的に実行されます。
2. サービスの開始: `podman compose --profile=database up -d`
3. サービスの停止: `podman compose --profile=database down`

### QueryPie ACP ツールの実行

1. ツールの開始: `podman compose --profile=tools up -d`
2. マイグレーションの実行: `podman compose --profile=tools exec tools /app/script/migrate.sh runall`
3. ツールの停止: `podman compose --profile=tools down`

### QueryPie ACP アプリケーションの実行

1. アプリケーションの開始: `podman compose --profile=app up -d`
2. 正常な実行の確認: `podman compose --profile=app exec app readyz`
3. アプリケーションの停止: `podman compose --profile=app down`

## Docker で QueryPie ACP を手動で実行する

### MySQL と Redis の実行

1. `.env` ファイルの作成
   - `.env.template` をコピーして `.env` ファイルを作成し、必要な環境変数の値を設定します。
   - コマンド: `cp .env.template .env`、次に `vi .env`
   - 注意: `setup.v2.sh` スクリプトを使用すると、この手順は自動的に実行されます。
2. サービスの開始: `docker compose --profile=database up -d`
3. サービスの停止: `docker compose --profile=database down`

### QueryPie ACP ツールの実行

1. ツールの開始: `docker compose --profile=tools up -d`
2. マイグレーションの実行: `docker compose --profile=tools exec tools /app/script/migrate.sh runall`
3. ツールの停止: `docker compose --profile=tools down`

### QueryPie ACP アプリケーションの実行

1. アプリケーションの開始: `docker compose --profile=app up -d`
2. 正常な実行の確認: `docker compose --profile=app exec app readyz`
3. アプリケーションの停止: `docker compose --profile=app down`

## 技術サポートのお問い合わせ

[技術サポート](https://docs.querypie.com/ja/support) ページをご参照ください。