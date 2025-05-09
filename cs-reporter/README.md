# CS Reporter - 에이전트 네트워크 진단 도구

이 디렉토리에는 에이전트와 특정 웹/호스트 서비스 간의 네트워크 연결 문제를 진단하는 데 도움이 되는 스크립트들이 포함되어 있습니다.

## 스크립트 목록

*   `agent_diag_mac.sh`: **macOS**용 특정 엔드포인트 대상 네트워크 진단 스크립트 (Bash/zsh 사용)
*   `agent_diag_win.ps1`: **Windows**용 특정 엔드포인트 대상 네트워크 진단 스크립트 (PowerShell 사용)
*   `querypie_cs_report.sh`: **macOS/Linux**용 종합 진단 정보 수집 스크립트 (Bash/zsh 사용)
*   `conn_checker.sh`: **macOS/Linux**용 특정 호스트 및 포트 연결 확인 스크립트 (Bash/zsh 사용)
*   `conn_checker.ps1`: **Windows**용 특정 호스트 및 포트 연결 확인 스크립트 (PowerShell 사용)

## 목적

*   `agent_diag_*` 스크립트: 사용자가 지정한 웹 도메인과 호스트 도메인에 대해 네트워크 검사를 수행하여 DNS, 프록시, 방화벽, TLS 인증서 등 특정 연결 문제를 식별합니다.
*   `querypie_cs_report.sh`: 시스템 및 네트워크 환경 전반에 대한 진단 정보를 수집하여 문제 해결에 필요한 종합적인 데이터를 제공합니다.
*   `conn_checker.*` 스크립트: 지정된 호스트와 포트로의 기본적인 TCP 네트워크 연결 가능성을 빠르게 확인합니다. 방화벽 규칙이나 서비스 리스닝 상태를 간단히 점검하는 데 유용합니다.

## 주요 기능 (`agent_diag_*` 스크립트)

두 스크립트 모두 다음과 같은 검사를 수행합니다:

1.  **프록시 설정 확인:** 일반적인 프록시 환경 변수(`http_proxy`, `https_proxy`, `no_proxy` 등) 설정을 감지하여 출력합니다.
2.  **웹 도메인 IP 확인:** 제공된 웹 도메인의 IP 주소를 DNS를 통해 조회합니다 (macOS: `dig`, Windows: `Resolve-DnsName`).
3.  **웹 도메인 버전 확인:** `{스키마}{웹 도메인}/version` URL에 접속을 시도하고 연결 상세 정보(헤더 등)와 응답 내용을 출력합니다 (macOS: `curl -v`, Windows: `Invoke-WebRequest`). 스키마(`http://` 또는 `https://`)는 입력값에서 자동으로 감지하거나 기본값으로 `https://`를 사용합니다.
4.  **에이전트 다운로드 테스트:** 에이전트 파일(`{스키마}{웹 도메인}/agent/osx/arm64/QueryPieAgent.dmg` - 실제 경로는 다를 수 있음) 다운로드를 시뮬레이션하고 소요 시간을 측정합니다. 실제 파일은 저장되지 않습니다 (macOS: `curl`, Windows: `Invoke-WebRequest`).
5.  **호스트 도메인 IP 확인:** 제공된 호스트 도메인의 IP 주소를 DNS를 통해 조회합니다.
6.  **호스트 도메인 TLS 인증서 확인:** 호스트 도메인의 9000번 포트(TLS 포트로 가정)로 연결하여 서버가 제공하는 TLS 인증서의 상세 정보를 출력합니다 (macOS: `openssl s_client`, Windows: .NET `SslStream`).

## 사전 요구 사항

*   **macOS (`agent_diag_mac.sh`, `querypie_cs_report.sh`, `conn_checker.sh`):**
    *   Bash 또는 zsh 호환 셸 (macOS 기본)
    *   `dig` 명령어 (macOS 네트워크 도구에 포함되어 있거나 `brew install bind`로 설치 가능)
    *   `openssl` 명령어 (macOS에 기본 포함)
    *   `conn_checker.sh`의 경우: `nc` (netcat) 또는 `telnet` 명령어가 필요할 수 있습니다 (대부분의 macOS/Linux 시스템에 기본 포함).
    *   (`querypie_cs_report.sh`의 경우 추가적인 시스템 명령어가 필요할 수 있습니다.)
*   **Windows (`agent_diag_win.ps1`, `conn_checker.ps1`):**
    *   PowerShell (최신 Windows 버전에 기본 포함). `conn_checker.ps1`은 PowerShell 4.0 이상 (`Test-NetConnection` cmdlet 필요)이 권장됩니다.
    *   .NET Framework (일반적으로 기본 포함)

## 사용 방법

### agent_diag_mac.sh (macOS 특정 엔드포인트 진단)

1.  스크립트에 실행 권한을 부여합니다:
    ```bash
    chmod +x cs-reporter/agent_diag_mac.sh
    ```
2.  터미널에서 스크립트를 실행하며, 첫 번째 인자로 웹 도메인(스키마 포함/미포함 가능), 두 번째 인자로 호스트 도메인을 전달합니다:
    ```bash
    ./cs-reporter/agent_diag_mac.sh <web_domain_or_url> <host_domain>
    ```
    **예시:**
    ```bash
    ./cs-reporter/agent_diag_mac.sh https://querypie.example.com querypie-proxy.example.com
    ./cs-reporter/agent_diag_mac.sh querypie.example.com querypie-proxy.example.com
    ```

### agent_diag_win.ps1 (Windows 특정 엔드포인트 진단)

1.  **파일로 저장하여 실행 (권장):**
    *   PowerShell을 실행합니다. **(참고: 일부 네트워크 작업이나 권한 문제 발생 시, '관리자 권한으로 실행' 옵션을 사용하여 PowerShell 창을 여는 것이 도움이 될 수 있습니다.)**
    *   현재 세션의 스크립트 실행 정책 변경이 필요할 수 있습니다:
        ```powershell
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
        ```
    *   스크립트를 실행하며, 첫 번째 인자로 웹 도메인(스키마 포함/미포함 가능), 두 번째 인자로 호스트 도메인을 전달합니다:
        ```powershell
        .\cs-reporter\agent_diag_win.ps1 <web_domain_or_url> <host_domain>
        ```
        **예시:**
        ```powershell
        .\cs-reporter\agent_diag_win.ps1 https://querypie.example.com querypie-proxy.example.com
        .\cs-reporter\agent_diag_win.ps1 querypie.example.com querypie-proxy.example.com
        ```

2.  **스크립트 내용 복사 및 붙여넣기로 실행:**
    *   `.ps1` 파일을 저장하거나 실행 정책을 변경하고 싶지 않은 경우 사용할 수 있는 방법입니다.
    *   `agent_diag_win.ps1` 파일의 **전체 내용**을 복사합니다.
    *   PowerShell 창을 엽니다. **(참고: 일부 네트워크 작업이나 권한 문제 발생 시, '관리자 권한으로 실행' 옵션을 사용하여 PowerShell 창을 여는 것이 도움이 될 수 있습니다.)**
    *   복사한 내용을 PowerShell 창에 **붙여넣기** 합니다. 스크립트 코드가 터미널에 표시됩니다.
    *   **Enter** 키를 누릅니다.
    *   스크립트가 파라미터 입력을 요구할 것입니다. 다음과 같이 차례대로 입력합니다:
        *   `WebDomainInput:` 프롬프트가 나타나면 웹 도메인 또는 URL을 입력하고 Enter 키를 누릅니다.
        *   `HostDomain:` 프롬프트가 나타나면 호스트 도메인을 입력하고 Enter 키를 누릅니다.
    *   이후 스크립트가 진단을 시작합니다.

### querypie_cs_report.sh (서버 종합 진단 정보 수집)

이 스크립트는 시스템 및 네트워크 관련 상세 진단 정보를 수집하여 결과 디렉토리에 저장합니다.

1.  스크립트에 실행 권한을 부여합니다:
    ```bash
    chmod +x cs-reporter/querypie_cs_report.sh
    ```
2.  터미널에서 스크립트를 실행합니다.
    *(참고: 스크립트에 따라 특정 파라미터(예: 출력 디렉토리 이름)가 필요할 수 있습니다. 스크립트 내부 주석이나 별도 안내를 확인하세요. 아래는 파라미터가 없는 경우의 예시입니다.)*
    ```bash
    ./cs-reporter/querypie_cs_report.sh # 자동으로 QueryPie docker container 이름을 찾습니다.
    ./cs-reporter/querypie_cs_report.sh querypie-app-1    
    ```
3.  스크립트 실행이 완료되면 현재 디렉토리에 `querypie_cs_report/YYYYMMDD` 와 같은 형식의 이름 (또는 스크립트에서 지정한 다른 이름)을 가진 **결과 디렉토리**가 생성됩니다. 이 디렉토리에는 문제 해결에 필요한 로그 및 설정 파일 등 다양한 진단 정보가 포함되어 있습니다.
4.  **생성된 결과 디렉토리를 압축합니다:** 압축 도구(`zip`, `tar` 등)를 사용하여 `querypie_cs_report` 디렉토리를 하나의 파일로 만듭니다.
    *   **zip 사용 시:**
        ```bash
        zip -r querypie_cs_report.zip querypie_cs_report/
        ```
    *   **tar.gz 사용 시:**
        ```bash
        tar -czvf querypie_cs_report.tar.gz querypie_cs_report/
        ```
5.  **압축된 결과 파일(`querypie_cs_report.zip` 또는 `querypie_cs_report.tar.gz`)을 지원팀이나 담당자에게 전달해 주세요.** 이 파일은 문제 원인 분석에 사용됩니다.

### conn_checker.sh (macOS/Linux 특정 호스트/포트 연결 확인)

이 스크립트는 지정된 호스트와 포트로의 TCP 연결을 시도하여 네트워크 연결성을 확인합니다.

1.  스크립트에 실행 권한을 부여합니다:
    ```bash
    chmod +x cs-reporter/conn_checker.sh
    ```
2.  터미널에서 스크립트를 실행하며, 첫 번째 인자로 대상 호스트(IP 주소 또는 도메인 이름), 두 번째 인자로 대상 포트 번호를 전달합니다:
    ```bash
    ./cs-reporter/conn_checker.sh <target_host> <target_port>
    ```
    **예시:**
    ```bash
    # querypie-proxy.example.com 의 9000번 포트 연결 확인
    ./cs-reporter/conn_checker.sh querypie-proxy.example.com 9000

    # IP 주소 192.168.1.100 의 3306번 포트 연결 확인
    ./cs-reporter/conn_checker.sh 192.168.1.100 3306
    ```
3.  **결과 확인:**
    *   스크립트는 일반적으로 연결 성공 또는 실패 메시지를 출력합니다.
    *   연결에 성공하면 "Connection to <target_host> <target_port> succeeded!" 와 유사한 메시지가 표시될 수 있습니다.
    *   연결에 실패하면 "Connection to <target_host> <target_port> failed!" 또는 `nc`/`telnet`의 오류 메시지(예: "Connection timed out", "Connection refused")가 표시될 수 있습니다.
    *   방화벽에 의해 차단되거나, 해당 포트에서 서비스가 실행 중이지 않거나, 네트워크 경로에 문제가 있는 경우 연결에 실패할 수 있습니다.

### conn_checker.ps1 (Windows 특정 호스트/포트 연결 확인)

이 스크립트는 지정된 호스트와 포트로의 TCP 연결을 시도하여 네트워크 연결성을 확인합니다 (`Test-NetConnection` cmdlet 사용).

1.  PowerShell을 실행합니다. (참고: 일반 사용자 권한으로도 실행 가능하나, 네트워크 문제 진단 시 관리자 권한이 더 많은 정보를 제공할 수 있습니다.)
2.  필요한 경우 현재 세션의 스크립트 실행 정책을 변경합니다:
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
    ```
3.  스크립트를 실행하며, 대상 호스트와 포트를 파라미터로 전달합니다:
    ```powershell
    # 명명된 파라미터 사용 (권장)
    .\cs-reporter\conn_checker.ps1 -TargetHost <target_host> -TargetPort <target_port>

    # 위치 기반 파라미터 사용
    .\cs-reporter\conn_checker.ps1 <target_host> <target_port>
    ```
    **예시:**
    ```powershell
    # querypie-proxy.example.com 의 9000번 포트 연결 확인
    .\cs-reporter\conn_checker.ps1 -TargetHost querypie-proxy.example.com -TargetPort 9000

    # IP 주소 192.168.1.100 의 3306번 포트 연결 확인
    .\cs-reporter\conn_checker.ps1 192.168.1.100 3306
    ```
4.  **결과 확인:**
    *   스크립트는 연결 성공 또는 실패 메시지를 명확하게 출력합니다.
    *   연결 성공 시 "결과: 연결 성공!" 메시지와 함께 `Test-NetConnection`의 상세 결과가 표시될 수 있습니다.
    *   연결 실패 시 "결과: 연결 실패." 메시지와 함께 가능한 원인 목록 및 상세 오류 확인을 위한 직접 실행 명령어를 안내합니다.

## 결과 해석

스크립트는 가독성을 위해 색상을 사용합니다:
*   **파란색:** 섹션 제목 및 정보 메시지
*   **초록색:** 성공적인 작업 또는 긍정적인 결과
*   **노란색:** 경고 또는 참고할 만한 설정 (예: 감지된 프록시)
*   **빨간색:** 오류 또는 실패

`agent_diag_*` 스크립트 출력 내용에서 빨간색 오류 메시지가 있는지 확인하여 잠재적인 문제를 파악하세요. DNS 결과, 프록시 설정, 인증서 정보 등이 예상과 다르거나 일치하지 않는지 검토합니다.

`querypie_cs_report.sh` 스크립트는 직접적인 결과 해석보다는 생성된 결과 디렉토리의 내용을 전달하는 것이 주 목적입니다.

`conn_checker.*` 스크립트는 간단한 연결 성공/실패 여부를 통해 기본적인 네트워크 경로 및 포트 접근성을 판단하는 데 사용됩니다. 