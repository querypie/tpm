# AWS Marketplace AMI 빌드 가이드

## 개요

이 디렉토리에는 QueryPie AMI를 빌드하고 검증하기 위한 Packer 스크립트가 있습니다.

| 파일 | 설명 |
|------|------|
| `ami-build.pkr.hcl` | AMI 빌드 Packer 템플릿 (Spot Instance 사용) |
| `ami-verify.pkr.hcl` | 빌드된 AMI 검증 Packer 템플릿 |
| `ami-build.sh` | `ami-build.pkr.hcl` 실행 래퍼 스크립트 |
| `ami-verify.sh` | `ami-verify.pkr.hcl` 실행 래퍼 스크립트 |
| `querypie-first-boot.service` | AMI 최초 부팅 시 QueryPie 설치를 완료하는 systemd 서비스 |

## IAM 권한 설정

### 계정 정보

- **AWS 계정 ID**: `142605707876`
- **리전**: `ap-northeast-2` (서울)
- **IAM 유저**: `JK`

### PackerAMIBuilder 정책

`JK` IAM 유저에는 `PackerAMIBuilder` 커스텀 정책이 연결되어 있습니다.
이 정책은 Packer가 AMI 빌드에 필요한 최소 권한만 허용합니다.

```
arn:aws:iam::142605707876:policy/PackerAMIBuilder
```

**정책 구성:**

| Sid | 허용 액션 | 용도 |
|-----|-----------|------|
| `PackerAMIDataSource` | `ec2:DescribeImages`, `ec2:DescribeRegions`, `ec2:DescribeSubnets` 외 조회성 액션 | 베이스 AMI 탐색, 리소스 상태 조회 |
| `PackerSpotInstance` | `ec2:CreateFleet`, `ec2:CreateLaunchTemplate`, `ec2:RequestSpotInstances` 외 | Spot Fleet 인스턴스 생성 및 관리 |
| `PackerInstanceLifecycle` | `ec2:RunInstances`, `ec2:StopInstances`, `ec2:TerminateInstances` 외 | EC2 인스턴스 생명주기 관리 |
| `PackerSecurityGroup` | `ec2:CreateSecurityGroup`, `ec2:DeleteSecurityGroup`, `ec2:AuthorizeSecurityGroupIngress` 외 | 임시 보안 그룹 생성/삭제 |
| `PackerKeyPair` | `ec2:CreateKeyPair`, `ec2:DeleteKeyPair` | 임시 SSH 키페어 생성/삭제 |
| `PackerAMICreate` | `ec2:CreateImage`, `ec2:RegisterImage`, `ec2:ModifyImageAttribute` 외 | AMI 생성 및 속성 수정 |
| `PackerEBSVolume` | `ec2:CreateVolume`, `ec2:DeleteVolume`, `ec2:AttachVolume`, `ec2:DetachVolume` | EBS 볼륨 관리 |
| `PackerSnapshot` | `ec2:CreateSnapshot`, `ec2:DeleteSnapshot`, `ec2:ModifySnapshotAttribute` | EBS 스냅샷 관리 |
| `PackerTags` | `ec2:CreateTags` | 리소스 태그 추가 |

> **참고**: `AmazonEC2FullAccess` 대신 최소 권한 원칙에 따라 커스텀 정책을 사용합니다.
> 불필요한 VPC 생성/삭제, 인터넷 게이트웨이 등의 권한은 포함되지 않습니다.

### AWS 자격 증명 설정

`JK` IAM 유저의 액세스 키를 `[default]` 프로파일로 설정합니다.

```bash
aws configure
# AWS Access Key ID: <JK 유저의 액세스 키 ID>
# AWS Secret Access Key: <JK 유저의 시크릿 액세스 키>
# Default region name: ap-northeast-2
# Default output format: json
```

설정 확인:

```bash
aws sts get-caller-identity
# 예상 출력:
# {
#   "UserId": "AIDASCM7WNJSBH6TKALFI",
#   "Account": "142605707876",
#   "Arn": "arn:aws:iam::142605707876:user/JK"
# }
```

## 빌드 환경 준비 (macOS 기준)

### 1. AWS CLI 설치

```bash
brew install awscli
aws --version
```

### 2. Packer 설치

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/packer
packer --version
```

### 3. Packer 플러그인 초기화

```bash
cd aws/ami
packer init ami-build.pkr.hcl
```

## AMI 빌드

### 기본 빌드

```bash
cd aws/ami
./ami-build.sh <querypie_version>

# 예시: QueryPie 11.6.0 빌드
./ami-build.sh 11.6.0
```

### 아키텍처 지정 빌드

```bash
# x86_64 (기본값)
./ami-build.sh 11.6.0 amazon-linux-2023 x86_64

# arm64
./ami-build.sh 11.6.0 amazon-linux-2023 arm64
```

### 릴리즈 모드 빌드

타임스탬프 없이 `QueryPie-Suite-<version>` 이름으로 AMI를 생성합니다.

```bash
MODE=release ./ami-build.sh 11.6.0
```

### 빌드 흐름

```
ami-build.sh 실행
    │
    ▼
베이스 AMI 탐색 (al2023-ami-2023.10.*)
    │
    ▼
Spot Fleet 인스턴스 기동 (t3.xlarge, ~$0.078/시간)
    │
    ▼
cloud-init 완료 대기
    │
    ▼
Docker 설치 (install-docker-on-amazon-linux-2023.sh)
    │
    ▼
setup.v2.sh 설치 (/usr/local/bin/setup.v2.sh)
    │
    ▼
QueryPie 부분 설치 (이미지 Pull, compose.yml 설정)
setup.v2.sh --install-partially-for-ami <version>
    │
    ▼
querypie-first-boot.service 등록 (최초 부팅 시 설치 완료)
    │
    ▼
최종 정리 (로그, 히스토리, 임시 파일 삭제)
    │
    ▼
AMI 생성 및 태그 부착
    │
    ▼
manifest.json 생성
```

> 전체 빌드 시간은 약 7~10분입니다.

## AMI 검증

빌드된 AMI를 검증합니다. 해당 AMI로 EC2 인스턴스를 기동하여 QueryPie 설치 상태를 확인합니다.

```bash
./ami-verify.sh <AMI_ID>

# 예시
./ami-verify.sh ami-020ae861e3194f2b7
```

> `ami-verify.pkr.hcl`은 `skip_create_ami = true`로 설정되어 있어,
> 검증용 인스턴스를 기동하고 테스트 후 AMI를 새로 생성하지 않고 종료합니다.

## 트러블슈팅

### UnauthorizedOperation: ec2:DescribeImages

```
User: arn:aws:iam::142605707876:user/JK is not authorized to perform:
  ec2:DescribeImages
```

`PackerAMIBuilder` 정책이 `JK` 유저에 연결되어 있는지 확인합니다.

```bash
aws iam list-attached-user-policies --user-name JK
```

연결되지 않은 경우:

```bash
aws iam attach-user-policy \
  --user-name JK \
  --policy-arn arn:aws:iam::142605707876:policy/PackerAMIBuilder
```

### UnauthorizedOperation: ec2:CreateFleet

```
User: arn:aws:iam::142605707876:user/JK is not authorized to perform:
  ec2:CreateFleet
```

`PackerAMIBuilder` 정책이 v3 이상인지 확인합니다.
v1, v2는 `ec2:CreateFleet`이 누락되어 있습니다.

```bash
aws iam get-policy \
  --policy-arn arn:aws:iam::142605707876:policy/PackerAMIBuilder \
  --query 'Policy.DefaultVersionId'
# "v3" 이상이어야 함
```

### No AMI was found matching filters

```
Error: Datasource.Execute failed: No AMI was found matching filters
  name: "al2023-ami-2023.8.*"
```

`ami-build.pkr.hcl`의 AMI 필터가 오래된 버전을 가리키고 있습니다.
현재 유효한 필터는 `al2023-ami-2023.10.*`입니다.

현재 사용 가능한 최신 베이스 AMI를 확인하려면:

```bash
# x86_64
aws ec2 describe-images \
  --filters "Name=name,Values=al2023-ami-2023.*" \
            "Name=root-device-type,Values=ebs" \
            "Name=virtualization-type,Values=hvm" \
            "Name=architecture,Values=x86_64" \
  --owners amazon \
  --region ap-northeast-2 \
  --query 'sort_by(Images, &CreationDate)[-1].{Name:Name,ImageId:ImageId}'

# arm64
aws ec2 describe-images \
  --filters "Name=name,Values=al2023-ami-2023.*" \
            "Name=root-device-type,Values=ebs" \
            "Name=virtualization-type,Values=hvm" \
            "Name=architecture,Values=arm64" \
  --owners amazon \
  --region ap-northeast-2 \
  --query 'sort_by(Images, &CreationDate)[-1].{Name:Name,ImageId:ImageId}'
```

### 빌드 실패 시 디버깅

`PACKER_OPTION=-on-error=abort`를 사용하면 빌드 실패 시 EC2 인스턴스가 종료되지 않고
SSH로 접속하여 원인을 분석할 수 있습니다.

```bash
PACKER_OPTION=-on-error=abort ./ami-build.sh 11.6.0
```

> 디버깅 후 EC2 인스턴스를 수동으로 종료해야 합니다.
