# Usage instructions

## English - AWS source

1. Subscribe to QueryPie ACP Community Edition in AWS Marketplace and launch the AMI as an Amazon EC2 instance.
2. Configure the instance security group to allow inbound TCP port `8443` only from the trusted network that will access the QueryPie ACP web console.
3. Typically within three minutes after the instance enters the `Running` state, open `https://<instance-address>:8443/` in a web browser.
4. Verify that the QueryPie ACP initial page is displayed.

`<instance-address>` is the reachable DNS name or IP address of the launched EC2 instance.
For detailed configuration and usage after verifying access, see the [QueryPie ACP Community Edition Installation and Usage Guide](https://docs.querypie.com/installation/querypie-acp-community-edition).
QueryPie ACP is preinstalled in the Marketplace AMI, so do not run the general Linux installation command in the linked guide.

## English - optional SSH verification

To verify the container status from the instance, allow inbound TCP port `22` only from a trusted administrator network and connect with the key pair selected when the instance was launched.

```bash
ssh -i <private-key-file> ec2-user@<instance-address>
```

Run the following command from the `ec2-user` home directory.

```bash
/usr/local/bin/setup.v2.sh --verify-installation
```

A healthy installation ends with `Installation verification completed successfully.`
The command checks the first-boot service, Docker, the installed version, the QueryPie application container, and the application readiness endpoint.

## 한국어 리뷰용 번역

1. AWS Marketplace에서 QueryPie ACP Community Edition을 구독하고 AMI를 Amazon EC2 인스턴스로 실행합니다.
2. QueryPie ACP 웹 콘솔에 접근할 신뢰된 네트워크에서만 TCP `8443` 포트로 인바운드 연결할 수 있도록 인스턴스 보안 그룹을 구성합니다.
3. 일반적으로 인스턴스가 `Running` 상태가 된 시점부터 3분 이내에 웹 브라우저에서 `https://<instance-address>:8443/`를 엽니다.
4. QueryPie ACP 초기 화면이 표시되는지 확인합니다.

`<instance-address>`는 실행한 EC2 인스턴스에 접근할 수 있는 DNS 이름 또는 IP 주소입니다.
접속 확인 이후의 자세한 설정과 사용 방법은 [QueryPie ACP Community Edition 설치 및 사용 가이드](https://docs.querypie.com/installation/querypie-acp-community-edition)를 참조합니다.
Marketplace AMI에는 QueryPie ACP가 사전 설치되어 있으므로 연결된 가이드의 일반 Linux 설치 명령을 실행하지 않습니다.

## 한국어 리뷰용 SSH 확인 절차

인스턴스 내부에서 컨테이너 상태를 확인하려면 신뢰된 관리자 네트워크에서만 TCP `22` 포트로 인바운드 연결을 허용하고, 인스턴스 실행 시 선택한 키 페어를 사용해 접속합니다.

```bash
ssh -i <private-key-file> ec2-user@<instance-address>
```

`ec2-user` 홈 디렉토리에서 다음 명령을 실행합니다.

```bash
/usr/local/bin/setup.v2.sh --verify-installation
```

정상 상태이면 마지막에 `Installation verification completed successfully.`가 출력됩니다.
이 명령은 최초 부팅 서비스, Docker, 설치 버전, QueryPie 애플리케이션 컨테이너와 애플리케이션 준비 상태를 함께 확인합니다.

## 작성 범위

Marketplace에 제출하는 기본 지침은 AMI 실행 후 일반적으로 3분 이내에 `https://<instance-address>:8443/` 접속을 확인하는 방법을 설명합니다.
선택적 SSH 절차는 `ec2-user`로 접속해 컨테이너와 애플리케이션 준비 상태를 확인하는 방법만 설명합니다.
라이선스 발급 또는 설치 단계는 이 지침에 포함하지 않습니다.
