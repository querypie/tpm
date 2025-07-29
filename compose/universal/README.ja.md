# Podman Compose と Docker Compose のための QueryPie 実行環境

最終更新日: 2025年7月28日

このリポジトリは、Podman と Podman Compose をサポートする QueryPie 実行環境を提供します。
また、代替として Docker と Docker Compose を使用できる互換性設定も含まれています。
以下のガイドでは、Podman と Podman Compose を使用して QueryPie を実行する方法について説明します。

## QueryPie を自動的にインストールして実行する

「Podman と Podman Compose のインストール方法」セクションを参照して、まず podman と podman-compose をインストールしてください。

Linux サーバーのシェルで次のコマンドを実行します。`--universal` オプションを省略してはいけないことに注意してください。
```shell
$ bash <(curl -s https://dl.querypie.com/setup.v2.sh) --universal
```
または、次の方法を使用することもできます：
```shell
$ curl -s https://dl.querypie.com/setup.v2.sh -o setup.v2.sh
$ bash setup.v2.sh --universal
```

`setup.v2.sh` を使用したインストールの詳細なガイドについては、次のドキュメントを参照してください：
[Installation Guide - setup.v2.sh (JA)](https://querypie.atlassian.net/wiki/spaces/QCP/pages/1177387032/Installation+Guide+-+setup.v2.sh+JA)


## QueryPie を手動で実行する

### MySQL と Redis の実行

1. `.env` ファイルの作成
   - `.env.template` をコピーして `.env` ファイルを作成し、必要な環境変数の値を設定します。
   - コマンド: `cp .env.template .env`、次に `vi .env`
   - 注意: `setup.v2.sh` スクリプトを使用すると、この手順は自動的に実行されます。
2. サービスの開始: `podman-compose --profile=database up -d`
3. サービスの停止: `podman-compose --profile=database down`

### ツールの実行

1. ツールの開始: `podman-compose --profile=tools up -d`
2. マイグレーションの実行: `podman-compose --profile=tools exec tools /app/script/migrate.sh runall`
3. ツールの停止: `podman-compose --profile=tools down`

### QueryPie アプリケーションの実行

1. アプリケーションの開始: `podman-compose --profile=app up -d`
2. 正常な実行の確認: `podman-compose --profile=app exec app readyz`
3. アプリケーションの停止: `podman-compose --profile=app down`

## Compose YAML の変更点

Podman Compose と Docker Compose 間の互換性を確保するために、以下の変更が行われています:

- コンテナ名を指定する際に、区切り文字として `_` の代わりに `-` を使用するように設定を追加しました。
  - Podman Compose はデフォルトの区切り文字として `_` を使用します。Docker Compose v2 と互換性を持たせるには、`-` を使用する必要があります。
  - `x-podman: name_separator_compat: true` の設定を追加しました。
  - 注意: Docker Compose v1 は区切り文字として `_` を使用し、v2 は `-` を使用します。
- Docker イメージレジストリとして `docker.io/` レジストリを使用するように指定しました。
  - レジストリが指定されていない場合、イメージをダウンロードする際に Podman Compose は RHEL レジストリを使用するかどうかを選択するプロンプトを表示します。

## Podman と Podman Compose のインストール方法

多くの Linux ディストリビューションでは、Podman と Podman Compose をディストリビューションパッケージとして提供しています。
ただし、Amazon Linux 2023 はデフォルトで Podman インストールパッケージを含んでいません。

### RHEL8 でのインストール

- Podman のインストール:
  - `sudo dnf install podman`
- Podman Compose のインストール:
  - `sudo dnf install -y python3.11 python3.11-pip python3.11-devel`
  - `python3.11 -m pip install --user podman-compose`
- インストールの確認:
  - `podman --version`
    - バージョン 4.9.4-rhel 以降であることを確認してください。
  - `python3.11 --version`
  - `podman-compose --version`
    - バージョン 1.5.0 以降であることを確認してください。

## SELinux 設定の変更

SELinux は Red Hat Enterprise Linux 8.9 (Ootpa) ではデフォルトで有効になっています。
Podman Compose を正常に使用するには、以下のように SELinux 設定を変更する必要があります:

- コンテナボリュームのマウントを許可するように SELinux 設定を変更:
  - `cd podman`
  - `sudo chcon -Rt container_file_t .`
  - `sudo chcon -Rt container_file_t ../log`
- コンテナボリュームマウントターゲットの SELinux コンテキストを確認:
  - `cd podman`
  - `ls -dlZ * ../log`
  - `unconfined_u:object_r:container_file_t:s0` や `system_u:object_r:container_file_t:s0` のようなコンテキストが表示されるはずです。
  - `user_home_t` が表示される場合、コンテナボリュームマウントを許可しない SELinux 設定を示しています。

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

## テスト環境

この構成は以下の環境でテストされています:

- Red Hat Enterprise Linux release 8.9 (Ootpa) と Podman および Podman Compose:
  - podman-compose バージョン 1.5.0
  - podman バージョン 4.9.4-rhel
- Amazon Linux 2023 と Docker および Docker Compose:
  - Docker バージョン 25.0.8, ビルド 0bab007
  - Docker Compose バージョン v2.13.0