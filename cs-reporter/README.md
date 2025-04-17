# CS Reporter - 에이전트 네트워크 진단 도구

이 디렉토리에는 에이전트와 특정 웹/호스트 서비스 간의 네트워크 연결 문제를 진단하는 데 도움이 되는 스크립트들이 포함되어 있습니다.

## 스크립트 목록

*   `agent_diag_mac.sh`: **macOS**용 진단 스크립트 (Bash/zsh 사용)
*   `agent_diag_win.ps1`: **Windows**용 진단 스크립트 (PowerShell 사용)

## 목적

이 스크립트들은 사용자가 지정한 웹 도메인(설치 파일, 버전 정보 등이 위치할 수 있는 곳)과 호스트 도메인(일반적으로 API 또는 서비스 엔드포인트)에 대해 일련의 네트워크 검사를 수행합니다. 이를 통해 DNS 해석, 프록시 설정, 방화벽 차단, TLS 인증서 문제 등 잠재적인 연결 문제를 식별하는 데 도움을 줍니다.

## 주요 기능

두 스크립트 모두 다음과 같은 검사를 수행합니다:

1.  **프록시 설정 확인:** 일반적인 프록시 환경 변수(`http_proxy`, `https_proxy`, `no_proxy` 등) 설정을 감지하여 출력합니다.
2.  **웹 도메인 IP 확인:** 제공된 웹 도메인의 IP 주소를 DNS를 통해 조회합니다 (macOS: `dig`, Windows: `Resolve-DnsName`).
3.  **웹 도메인 버전 확인:** `{스키마}{웹 도메인}/version` URL에 접속을 시도하고 연결 상세 정보(헤더 등)와 응답 내용을 출력합니다 (macOS: `curl -v`, Windows: `Invoke-WebRequest`). 스키마(`http://` 또는 `https://`)는 입력값에서 자동으로 감지하거나 기본값으로 `https://`를 사용합니다.
4.  **에이전트 다운로드 테스트:** 에이전트 파일(`{스키마}{웹 도메인}/agent/osx/arm64/QueryPieAgent.dmg` - 실제 경로는 다를 수 있음) 다운로드를 시뮬레이션하고 소요 시간을 측정합니다. 실제 파일은 저장되지 않습니다 (macOS: `curl`, Windows: `Invoke-WebRequest`).
5.  **호스트 도메인 IP 확인:** 제공된 호스트 도메인의 IP 주소를 DNS를 통해 조회합니다.
6.  **호스트 도메인 TLS 인증서 확인:** 호스트 도메인의 9000번 포트(TLS 포트로 가정)로 연결하여 서버가 제공하는 TLS 인증서의 상세 정보를 출력합니다 (macOS: `openssl s_client`, Windows: .NET `SslStream`).

## 사전 요구 사항

*   **macOS (`agent_diag_mac.sh`):**
    *   Bash 또는 zsh 호환 셸 (macOS 기본)
    *   `dig` 명령어 (macOS 네트워크 도구에 포함되어 있거나 `brew install bind`로 설치 가능)
    *   `openssl` 명령어 (macOS에 기본 포함)
*   **Windows (`agent_diag_win.ps1`):**
    *   PowerShell (최신 Windows 버전에 기본 포함)
    *   .NET Framework (일반적으로 기본 포함)

## 사용 방법

### macOS

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

### Windows

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

## 결과 해석

스크립트는 가독성을 위해 색상을 사용합니다:
*   **파란색:** 섹션 제목 및 정보 메시지
*   **초록색:** 성공적인 작업 또는 긍정적인 결과
*   **노란색:** 경고 또는 참고할 만한 설정 (예: 감지된 프록시)
*   **빨간색:** 오류 또는 실패

출력 내용에서 빨간색 오류 메시지가 있는지 확인하여 잠재적인 문제를 파악하세요. DNS 결과, 프록시 설정, 인증서 정보 등이 예상과 다르거나 일치하지 않는지 검토합니다. 