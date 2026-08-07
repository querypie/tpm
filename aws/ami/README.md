# QueryPie AWS Marketplace AMI

## 문서 범위

이 문서는 `aws/ami` 디렉토리에 구현된 AMI 빌드, 검증 및 Sales 계정 승격의 현재 설정과 실행 동작을 설명합니다.
AWS Marketplace 판매자 등록과 제품 생성은 이 디렉토리에서 자동화하지 않습니다.

## 현재 실행 컨텍스트

QPE의 AMI 빌드는 다음 AWS 컨텍스트를 사용합니다.

| 항목 | 현재 값 |
|------|---------|
| AWS 계정 | QPE (`142605707876`) |
| 기본 빌드 리전 | 서울 (`ap-northeast-2`) |
| IAM 사용자 | `JK` |
| IAM ARN | `arn:aws:iam::142605707876:user/JK` |
| AWS CLI 프로파일 | 저장소에 설정 없음 |

저장소에는 AWS 자격 증명이나 AWS CLI 프로파일 설정이 포함되어 있지 않습니다.
모든 스크립트와 Packer는 실행 시점의 AWS 기본 자격 증명 체인을 그대로 사용합니다.
기본 빌드 리전은 다음 환경 변수로 설정됩니다.

```bash
export AMI_REGION=ap-northeast-2
```

`ami-build.sh`는 `aws sts get-caller-identity`의 성공 여부만 확인합니다.
스크립트는 응답의 계정 ID나 IAM ARN이 위 표의 값과 일치하는지 검사하지 않습니다.
`ami-verify.sh`, `ami-validate.sh`, `ami-ls.sh`도 계정이나 프로파일을 내부에서 변경하지 않습니다.

AMI 빌드와 인스턴스 검증에는 `packer`, `aws`, `session-manager-plugin` 명령이 필요합니다.
Packer는 Session Manager 플러그인을 사용해 빌드 및 검증 인스턴스에 대한 SSH 터널을 생성합니다.

## 파일과 호출 관계

사용자가 직접 실행하는 명령은 다음 다섯 개입니다.

| 파일 | 현재 동작 |
|------|-----------|
| `ami-build.sh` | Packer로 AMI를 생성한 후 `ami-validate.sh`를 실행 |
| `ami-verify.sh` | `ami-validate.sh`를 실행한 후 해당 AMI로 검증용 EC2 인스턴스를 기동 |
| `ami-validate.sh` | 현재 계정이 소유한 AMI와 EBS 스냅샷의 구조적 속성을 AWS API로 검사 |
| `ami-ls.sh` | 현재 AWS CLI 리전에서 소유자와 이름 조건에 맞는 AMI 목록을 출력 |
| `ami-promote-to-sales.sh` | 검증된 QPE AMI를 Sales 계정의 `us-east-1` 소유 AMI로 복사하고 임시 공유 권한을 회수 |

다음 파일은 위 명령이 내부에서 사용합니다.

| 파일 | 현재 동작 |
|------|-----------|
| `ami-build.pkr.hcl` | 빌드 인스턴스를 생성하고 QueryPie를 부분 설치한 뒤 AMI와 `manifest.json`을 생성 |
| `ami-verify.pkr.hcl` | 기존 AMI로 검증 인스턴스를 만들고 새 AMI를 생성하지 않은 채 설치 상태를 검사 |
| `validate-image-runtime.sh` | 인스턴스 내부의 암호화 블록 장치와 암호화 파일시스템을 검사 |
| `sanitize-image-before-snapshot.sh` | AMI 스냅샷 직전에 SSH, cloud-init, 로그 및 임시 상태를 정리 |
| `querypie-first-boot.service` | AMI로 만든 인스턴스가 처음 부팅될 때 QueryPie 설치를 재개 |

호출 관계는 다음과 같습니다.

```text
ami-build.sh
├── ami-build.pkr.hcl
│   ├── validate-image-runtime.sh
│   ├── sanitize-image-before-snapshot.sh
│   └── querypie-first-boot.service 설치
└── ami-validate.sh

ami-verify.sh
├── ami-validate.sh
└── ami-verify.pkr.hcl
    └── validate-image-runtime.sh

ami-promote-to-sales.sh
├── QPE AMI와 모든 backing snapshot을 Sales에 임시 공유
├── Sales 계정의 us-east-1 소유 AMI로 비암호화 복사
├── ami-validate.sh --marketplace-source
└── QPE AMI와 snapshot의 Sales 공유 권한 회수
```

## AMI 빌드

### 입력값

`ami-build.sh`의 인터페이스는 다음과 같습니다.

```text
./ami-build.sh <querypie_version> [<distro>] [<architecture>]
```

| 입력 | 기본값 | 현재 제약 |
|------|--------|-----------|
| `querypie_version` | 없음 | 필수 |
| `distro` | `amazon-linux-2023` | `amazon-linux-2023`만 허용 |
| `architecture` | `x86_64` | `x86_64` 또는 `arm64` |
| `AMI_REGION` | `ap-northeast-2` | Packer와 AWS API 호출에 동일한 값 전달 |
| `MODE` | 빈 값 | `release`일 때만 릴리즈 이름 사용 |
| `PACKER_OPTION` | 빈 값 | 값이 있으면 `packer build`에 그대로 전달 |

현재 QPE 실행 명령은 다음 형태입니다.

```bash
AMI_REGION=ap-northeast-2 \
  ./ami-build.sh <querypie_version> amazon-linux-2023 x86_64
```

`MODE=release`가 아니면 AMI 이름은 `QueryPie-Suite-<version>-<YYYYMMDDHHMM>`입니다.
`MODE=release`이면 AMI 이름은 `QueryPie-Suite-<version>`입니다.

### 빌드 전 검사

`ami-build.sh`는 Packer 실행 전에 다음 조건을 검사합니다.

1. `packer` 명령이 존재해야 합니다.
2. `aws` 명령이 존재해야 합니다.
3. `session-manager-plugin` 명령이 존재해야 합니다.
4. 현재 AWS 자격 증명으로 `sts get-caller-identity`가 성공해야 합니다.
5. `AMI_REGION`의 `EbsEncryptionByDefault` 값이 정확히 `False`여야 합니다.

EBS 기본 암호화가 활성화되어 있으면 Packer를 실행하지 않습니다.

### Packer 설정

`ami-build.pkr.hcl`의 현재 빌드 설정은 다음과 같습니다.

| 항목 | x86_64 | arm64 |
|------|--------|-------|
| 베이스 AMI 소유자 | `amazon` | `amazon` |
| 베이스 AMI 이름 | `al2023-ami-2023.12.*-kernel-6.12-*` | 동일 |
| 루트 장치 유형 | `ebs` | `ebs` |
| 가상화 유형 | `hvm` | `hvm` |
| 빌드 인스턴스 | Spot `t3.xlarge` | Spot `t4g.xlarge`, `m7g.xlarge`, `m6g.xlarge` 순서의 용량 대안 |

생성되는 AMI는 HVM과 ENA를 사용하고 IMDSv2를 요구합니다.
루트 볼륨은 `gp3`, 32 GiB, 16,000 IOPS, 1,000 MiB/s로 설정됩니다.
빌드 인스턴스와 AMI의 루트 볼륨은 암호화하지 않습니다.
Packer는 `ec2-session-manager` 인스턴스 프로파일과 Session Manager를 통해 SSH를 연결합니다.

### Packer 실행 순서

`ami-build.pkr.hcl`은 다음 순서로 인스턴스를 구성합니다.

1. `cloud-init status --wait`로 초기화 완료를 기다립니다.
2. QueryPie listener 범위 `40000-40030`을 커널 임시 포트 할당에서 제외합니다.
3. `../scripts/install-docker-on-amazon-linux-2023.sh`를 실행합니다.
   Docker Compose 플러그인은 최초 부팅 systemd 서비스에서도 사용할 수 있도록 시스템 경로에 설치합니다.
4. `compose/setup.v2.sh`를 `/usr/local/bin/setup.v2.sh`로 설치합니다.
5. `setup.v2.sh --install-partially-for-ami <querypie_version>`을 실행합니다.
6. `querypie-first-boot.service`를 설치하고 활성화합니다.
7. `validate-image-runtime.sh`로 암호화된 장치와 파일시스템이 없는지 검사합니다.
8. `sanitize-image-before-snapshot.sh`로 빌드 인스턴스 상태를 정리합니다.
9. AMI 스냅샷과 `manifest.json`을 생성합니다.

부분 설치 단계는 QueryPie 구성 파일을 배치하고 database, querypie, tools 프로파일의 컨테이너 이미지를 미리 받습니다.
부분 설치 단계는 `.env`의 `AGENT_SECRET`, `KEY_ENCRYPTION_KEY`, `DB_PASSWORD`, `REDIS_PASSWORD` 값을 비운 상태로 AMI를 생성합니다.

### 스냅샷 전 정리

`sanitize-image-before-snapshot.sh`는 다음 변경을 적용합니다.

- SSH 비밀번호 인증과 키보드 대화식 인증을 비활성화합니다.
- SSH root 로그인을 비활성화하고 root 계정을 잠급니다.
- `/root`와 `/home` 아래의 `authorized_keys`를 삭제합니다.
- 기존 SSH host key를 삭제합니다.
- `cloud-init clean --logs`를 실행하고 `/etc/machine-id`를 `uninitialized`로 초기화합니다.
- 별도로 남은 D-Bus machine ID를 삭제합니다.
- systemd random seed를 삭제합니다.
- DNF 캐시, 임시 파일, 셸 히스토리 및 로그 내용을 정리합니다.
- 비어 있지 않은 `authorized_keys`가 남아 있으면 빌드를 실패시킵니다.

### 빌드 결과

Packer는 다음 태그를 빌드 인스턴스, AMI 및 스냅샷에 공통으로 설정합니다.

| 태그 | 값 |
|------|----|
| `CreatedBy` | `Packer` |
| `Owner` | `AMI-Builder` |
| `Purpose` | `Automated QueryPie AMI Build` |
| `BuildDate` | Packer 타임스탬프 |
| `Version` | 입력한 QueryPie 버전 |

`manifest.json`의 `custom_data`에는 AMI 이름, QueryPie 버전, 빌드 타임스탬프, 베이스 AMI 이름, 리전 및 아키텍처가 기록됩니다.

Packer가 끝나면 `ami-build.sh`는 현재 계정과 빌드 리전에서 AMI 이름이 같은 가장 최근 이미지를 조회합니다.
조회한 AMI ID에 대해 `ami-validate.sh`가 성공해야 최종적으로 `Built AMI: <ami-id>`를 출력합니다.

## AMI 구조 검증

`ami-validate.sh`는 EC2 인스턴스를 생성하지 않습니다.
이 스크립트는 현재 AWS 자격 증명이 소유한 AMI만 `--owners self`로 조회합니다.

```bash
AMI_REGION=ap-northeast-2 \
  ./ami-validate.sh <ami-id>
```

현재 검사 항목은 다음과 같습니다.

| 검사 항목 | 허용 값 |
|-----------|---------|
| AMI 상태 | `available` |
| 루트 장치 유형 | `ebs` |
| 가상화 유형 | `hvm` |
| 아키텍처 | `x86_64` 또는 `arm64` |
| IMDS 지원 | `v2.0` |
| AMI 설명 | 빈 값이 아님 |
| EBS 스냅샷 | 하나 이상 존재 |
| 각 EBS 스냅샷의 `Encrypted` | `False` |
| EBS 볼륨 크기 합계 | 정수이며 5,120 GiB 이하 |

AMI 조회가 성공한 뒤 발견된 구조 검사 실패는 누적되며, 하나 이상의 실패가 있으면 종료 코드 `1`을 반환합니다.
AWS CLI 또는 AWS API 호출 자체가 실패하면 해당 시점에 즉시 중단됩니다.

### Marketplace 소스 모드

`--marketplace-source`는 위 구조 검사를 그대로 실행하면서 리전이 `us-east-1`인지 추가로 검사합니다.

```bash
AMI_REGION=us-east-1 \
  ./ami-validate.sh --marketplace-source <marketplace-ami-id>
```

이 옵션은 AMI를 판매자 계정으로 공유하거나 복사하지 않습니다.
실행 시점의 AWS 자격 증명이 해당 AMI를 소유한 계정이어야 합니다.
Sales 계정 선택과 복사는 별도의 `ami-promote-to-sales.sh`가 고정된 계정과 프로파일로 수행합니다.
Marketplace 제출, 스캔 실행 및 제품 등록도 이 옵션의 동작 범위에 포함되지 않습니다.

## AMI 인스턴스 검증

`ami-verify.sh`는 다음 순서로 실행됩니다.

1. `packer`, `aws`, `session-manager-plugin` 명령이 존재하는지 확인합니다.
2. `ami-validate.sh`로 AMI 구조를 검사합니다.
3. AWS API에서 AMI 아키텍처를 조회합니다.
4. `ami-verify.pkr.hcl`로 해당 AMI의 검증 인스턴스를 기동합니다.
5. 최초 부팅 설치 완료와 QueryPie 컨테이너 상태를 검사합니다.
6. `validate-image-runtime.sh`로 암호화된 장치와 파일시스템이 없는지 검사합니다.

현재 QPE 실행 명령은 다음 형태입니다.

```bash
AMI_REGION=ap-northeast-2 \
  ./ami-verify.sh <ami-id>
```

검증 인스턴스는 AMI 아키텍처에 따라 `t3.xlarge` 또는 `t4g.xlarge`를 사용합니다.
검증용 루트 볼륨은 임시 `gp3` 32 GiB 볼륨이며 암호화됩니다.
이 볼륨은 검증 인스턴스에만 연결되고 Marketplace 제출 AMI에는 포함되지 않습니다.
`skip_create_ami = true`이므로 검증 과정에서 새 AMI를 만들지 않습니다.

`setup.v2.sh --verify-installation`은 최초 부팅 완료 marker, systemd 서비스 상태, 컨테이너 엔진, 설치 버전 및 QueryPie 컨테이너 준비 상태를 확인합니다.
검증이 끝나면 `manifest.json`에는 검증 타임스탬프, 검증용 이름 및 리전이 기록됩니다.

## Sales 계정으로 Marketplace AMI 승격

`ami-promote-to-sales.sh`는 기능 검증을 통과한 QPE AMI를 Marketplace 제출에 사용할 Sales 소유 AMI로 승격합니다.
임의 계정이나 리전에 배포하는 용도가 아니므로 다음 값은 스크립트에 고정되어 있으며 옵션이나 환경 변수로 변경할 수 없습니다.

| 항목 | 고정값 |
|------|--------|
| QPE 계정 | `142605707876` |
| QPE AWS CLI 프로파일 | `qpe` |
| 소스 리전 | `ap-northeast-2` |
| Sales 계정 | `883790944456` |
| Sales AWS CLI 프로파일 | `sales` |
| 대상 리전 | `us-east-1` |
| 복사 암호화 | 비활성화 |

AWS CLI의 `qpe`, `sales` 프로파일은 저장소 밖에서 미리 설정하고 로그인해야 합니다.
스크립트는 두 프로파일의 호출 계정 ID를 검사하며 표의 계정과 다르면 어떤 공유 권한도 변경하지 않고 중단합니다.

승격 전에 QPE 자격 증명으로 기능 검증을 완료해야 합니다.

```bash
AWS_PROFILE=qpe \
AMI_REGION=ap-northeast-2 \
  ./ami-verify.sh <qpe-ami-id>
```

검증에 성공한 동일 AMI ID만 인자로 전달합니다.

```bash
./ami-promote-to-sales.sh <qpe-ami-id>
```

스크립트는 다음 순서로 실행됩니다.

1. `qpe`, `sales` 프로파일의 호출 계정 ID와 Sales `us-east-1`의 EBS 기본 암호화 비활성화를 확인합니다.
2. QPE AMI에 `ami-validate.sh`를 실행하고 모든 backing snapshot ID를 조회합니다.
3. QPE AMI의 launch permission과 모든 snapshot의 create-volume permission에 Sales 계정을 임시로 추가합니다.
4. Sales 자격 증명으로 AMI를 `us-east-1`에 비암호화 상태로 복사하고 AMI와 snapshot에 출처 태그를 적용합니다.
5. Sales AMI가 `available`이 될 때까지 최대 1시간 기다린 뒤 `ami-validate.sh --marketplace-source`를 실행합니다.
6. 검증에 성공하면 QPE AMI와 모든 backing snapshot에서 Sales 공유 권한을 제거합니다.

동일 QPE AMI에서 생성된 Sales AMI는 `SourceAMI`, `SourceAccount`, `SourceRegion` 태그로 식별합니다.
같은 릴리스 버전을 다시 빌드해도 기존 Sales AMI 이름과 충돌하지 않도록 Sales AMI 이름에는 소스 AMI ID가 자동으로 추가됩니다.
스크립트를 다시 실행했을 때 해당 Sales AMI가 이미 존재하면 새 복사를 만들지 않고 기존 AMI를 검증한 뒤 남은 QPE 공유 권한을 회수합니다.

복사 요청 전에 실패하면 이번 실행에서 추가한 공유 권한만 롤백합니다.
Sales AMI가 이미 `available`인 상태에서 최종 검증이 실패해도 원본 접근은 더 이상 필요하지 않으므로 공유 권한을 회수합니다.
복사가 아직 `pending`인 상태에서 타임아웃 또는 상태 확인 오류가 발생하면 진행 중인 복사를 방해하지 않도록 공유 권한을 유지하며, 같은 AMI ID로 명령을 다시 실행해 검증과 권한 회수를 재개할 수 있습니다.

## 최초 부팅 동작

빌드 중 설치되는 `querypie-first-boot.service`는 Docker와 네트워크가 준비된 뒤 실행됩니다.
`/var/lib/querypie/first-boot-done` 파일이 없을 때만 `/usr/local/bin/setup.v2.sh --resume`을 실행합니다.

`--resume`은 다음 동작을 수행합니다.

1. AMI에 부분 설치된 QueryPie 버전을 확인합니다.
2. `.env` 값을 채웁니다.
3. database와 tools 컨테이너를 시작합니다.
4. 데이터베이스 migration을 두 번 실행합니다.
5. tools 컨테이너를 종료하고 QueryPie 컨테이너를 시작합니다.
6. 현재 버전 심볼릭 링크를 갱신합니다.

서비스가 성공하면 `/var/lib/querypie/first-boot-done` marker를 생성합니다.
서비스 시작 제한 시간은 600초입니다.

## 런타임 암호화 검사

`validate-image-runtime.sh`는 빌드 인스턴스와 검증 인스턴스 안에서 실행됩니다.

다음 중 하나가 발견되면 종료 코드 `1`을 반환합니다.

- `lsblk` 결과에 `crypt` 장치 유형이 존재
- `lsblk` 결과에 `crypto_LUKS` 파일시스템이 존재
- `findmnt` 결과에 `ecryptfs`, `encfs`, `fuse.encfs`, `fuse.gocryptfs`가 존재

이 검사는 AWS API에서 확인할 수 없는 게스트 OS 내부 암호화 상태만 검사합니다.
AMI와 EBS 스냅샷의 구조적 속성은 `ami-validate.sh`가 별도로 검사합니다.

## AMI 목록 조회

`ami-ls.sh`는 현재 AWS CLI 리전에서 AMI를 조회합니다.
이 스크립트에는 `AMI_REGION` 처리나 `--region` 인자가 없으므로 프로파일 설정과 환경 변수를 포함한 AWS CLI의 기본 리전 해석 결과를 사용합니다.

```text
./ami-ls.sh [self|aws-marketplace|redhat|rocky|centos|canonical] [name-prefix]
```

첫 번째 인자의 기본값은 `self`입니다.
정해진 별칭이 아닌 값을 전달하면 그 값을 AWS 계정 ID로 사용합니다.
두 번째 인자는 AMI 이름의 prefix filter로 사용됩니다.

## 현재 자동화 범위 밖

다음 작업은 현재 `aws/ami` 스크립트가 수행하지 않습니다.

- AWS CLI 프로파일 또는 Access Key 생성
- IAM 정책 생성 또는 사용자 연결
- AWS Marketplace 제품 생성, 스캔 실행 및 공개 범위 변경
