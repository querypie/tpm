## QueryPie Terraform 설치 가이드

### 개요

이 가이드는 AWS에서 Terraform을 사용하여 QueryPie를 설치하고 구성하는 방법을 상세히 설명합니다.

### 사전 요구사항

시작하기 전에 다음이 준비되어 있어야 합니다:

- 적절한 권한이 부여된 AWS 계정
- AWS 서비스(EC2, VPC, 보안 그룹 등)에 대한 기본 지식
- Terraform 기본 사용법 숙지
- QueryPie 라이선스 파일(`.license.crt`)
- Docker 레지스트리 자격 증명 파일(이미지 풀링용)

### 시스템 요구사항

- **운영체제**: macOS, Linux 또는 WSL이 설치된 Windows
- **메모리**: 최소 8GB RAM
- **디스크 여유 공간**: 최소 5GB
- **네트워크**: 안정적인 인터넷 연결

---

## 1. AWS CLI 설정

### 1.1 AWS CLI 설치

AWS CLI는 AWS 서비스와 상호작용하기 위해 필요합니다.  
공식 문서를 참고하세요: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

macOS 예시:
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg ./AWSCLIV2.pkg -target /
which aws
aws --version
```

### 1.2 AWS CLI 구성

Terraform이 AWS에 액세스할 수 있도록 자격증명을 설정합니다:
```bash
aws configure --profile your-profile-name
# AWS Access Key ID [None]: your-access-key
# AWS Secret Access Key [None]: your-secret-key
# Default region name [None]: ap-northeast-2
# Default output format [None]: json
```

더 자세한 내용은 AWS 문서 참조: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html

---

## 2. Terraform 설치

Terraform을 통해 AWS 인프라를 프로비저닝합니다.

### 2.1 표준 설치

공식 문서: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

macOS(Homebrew) 예시:
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# 업그레이드 필요 시
brew update
brew upgrade hashicorp/tap/terraform
```

### 2.2 여러 버전 관리 (tfenv)

프로젝트마다 특정 Terraform 버전이 필요할 때:
```bash
brew install tfenv
tfenv install 1.5.5
tfenv use 1.5.5
terraform --version
```

### 2.3 Terraform 초기화
```bash
terraform init
```

---

## 3. QueryPie 설치

### 3.1 소스 코드 내려받기

```bash
# QueryPie Terraform 소스 코드 클론
git clone https://github.com/querypie/tpm.git

# Terraform 실행을 위한 디렉토리로 이동
cd tpm/terraform-install/querypie
```

### 3.2 구성 파일 준비

#### Docker 인증 설정

QueryPie 이미지를 풀링할 수 있도록 Docker 자격증명을 복사합니다:
```bash
cat ~/.docker/config.json > .docker-config.json
```
이 파일을 Terraform 변수 `docker_registry_credential_file`에 지정합니다.

#### QueryPie 라이선스

라이선스 파일을 프로젝트 디렉터리에 복사합니다:
```bash
cp /path/to/your/license.crt .license.crt
```

#### Terraform 변수 파일 (`.querypie.tfvars`)

아래 예시처럼 변수 파일을 생성하고, 각 항목에 설명 주석을 추가하세요.

```hcl
# QueryPie 설치 구성용 변수 파일

# AWS Region 및 프로필 설정
aws_region  = "ap-northeast-2"             # 리소스를 생성할 AWS 리전
aws_profile = "your-profile-name"          # AWS CLI 프로필 이름

# 리소스 태깅 정보
organization = "querypie"                  # 태그용 조직 이름
team         = "your-team"                 # 태그용 팀 이름
owner        = "your-name"                 # 태그용 소유자 이름
project      = "terraform"                 # 태그용 프로젝트 이름

# QueryPie 버전 및 파일 경로
querypie_version       = "10.2.8"          # 배포할 QueryPie 버전
querypie_crt           = ".license.crt"    # 라이선스 파일 경로
docker_registry_credential_file = ".docker-config.json"  # Docker 자격증명 파일 경로

# 활성화할 제품 목록 (쉼표로 구분)
products = "DAC, SAC, KAC, WAC"            # 사용할 QueryPie 제품

# EC2 인스턴스 사양
instance_type       = "m6i.xlarge"         # 권장 EC2 인스턴스 타입
os_type             = "amazon_linux"       # OS 종류 (amazon_linux, ubuntu, redhat)
create_new_key_pair = true                 # 새 키 페어 생성 여부

# 네트워크 설정
vpc_id                = "vpc-0123456789abcdef0"                # VPC ID
lb_allowed_cidr_blocks = ["203.0.113.0/24","198.51.100.0/24"]  # ELB 허용 CIDR
lb_subnet_ids          = ["subnet-0123456789abcdef0","subnet-0123456789abcdef1"]  # ELB 서브넷
agentless_proxy_ports  = "40000-40002"                         # 에이전트리스 프록시 포트 범위

# 로드 밸런서 설정
create_lb                  = true                          # ELB 생성 여부
querypie_domain_name       = "querypie.example.com"        # QueryPie 도메인
querypie_proxy_domain_name = "proxy.querypie.example.com"  # 프록시 도메인
aws_route53_zone_id        = "Z0123456789ABCDEFGHIJ"       # Route53 호스티드 존 ID
aws_acm_certificate_arn    = "arn:aws:acm:region:account:certificate/id"  # ACM 인증서 ARN

# 외부 DB 사용 옵션 (선택 사항)
use_external_db = false             # 외부 DB 사용 여부
# db_host        = "external-db.endpoint"
# db_username    = "querypie"
# db_password    = "your-password"

# 외부 Redis 사용 옵션 (선택 사항)
use_external_redis = false          # 외부 Redis 사용 여부
# redis_connection_mode = "STANDALONE"
# redis_nodes           = "redis.endpoint:6379"
# redis_password        = "your-redis-password"

# 고급 옵션 (선택 사항)
# ec2_block_device_volume_size = "50"  # 루트 볼륨 크기(GB)
# agent_secret                 = "your-agent-secret"
# key_encryption_key           = "your-encryption-key"
```

### 3.3 배포

#### 변경 내용 미리 보기
```bash
terraform plan -var-file=".querypie.tfvars"
```
변경 사항을 충분히 검토하세요.

#### 적용
```bash
terraform apply -var-file=".querypie.tfvars"
```
프롬프트에 `yes`를 입력하여 배포를 시작합니다.

### 3.4 접근

배포 완료 후 출력된 정보를 확인합니다:

- **QueryPie URL**: `https://your-querypie-domain-name`
- **EC2 인스턴스 ID**: SSH 접속 또는 문제 해결용
- **로드 밸런서 DNS**: 직접 접속용

---

## 4. 삭제

모든 리소스를 제거하려면:
```bash
terraform destroy -var-file=".querypie.tfvars"
```
`yes`를 입력하여 삭제를 확인하세요.

---

## 5. 프로젝트 구조

```
.
├── main.tf
├── variables.tf
├── outputs.tf
└── modules/
    ├── ec2/
    ├── iam/
    ├── networking/
    ├── security/
    └── elb/
```

- **ec2**: EC2 인스턴스 및 키 페어 관리
- **iam**: IAM 역할 및 정책 관리
- **networking**: 네트워킹 리소스 관리
- **security**: 보안 그룹 및 규칙 관리
- **elb**: 로드 밸런서 관리

---

## 6. 문제 해결

1. **Terraform 초기화 오류**  
   Terraform 초기화(`terraform init`)가 실패하면, 설치된 Terraform 버전을 확인하고 인터넷 연결 및 AWS 자격증명을 점검하세요.

2. **AWS 인증 오류**
    - AWS 자격증명이 올바른지 확인합니다.
    - IAM 사용자에게 필요한 권한이 있는지 검토합니다.
    - SSO 세션 토큰이 만료되지 않았는지 확인하세요.

3. **배포 실패**  
   에러 메시지에 표시된 리소스 이름을 기반으로, VPC·서브넷 등이 존재하는지, 그리고 충분한 권한이 있는지 점검하세요.

4. **QueryPie 접속 문제**
    - EC2 인스턴스가 정상 실행 중인지 확인합니다.
    - 보안 그룹에서 웹 인터페이스(HTTPS) 및 프록시 포트 접근이 허용되었는지 검토하세요.
    - 사용자 도메인의 DNS 전파 상태를 확인합니다.

5. **OS별 SSH 접속 오류**
    - `.querypie.tfvars`에서 지정한 `os_type`이 실제 OS와 일치하는지 확인하세요.
    - Ubuntu의 경우 기본 사용자가 `ubuntu`이며, Red Hat은 추가 라이선스가 필요할 수 있습니다.

---

## 7. 추가 자료

- [QueryPie 문서](https://docs.querypie.com)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CLI 문서](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html)
- [Terraform 모범 사례](https://www.terraform-best-practices.com/)
