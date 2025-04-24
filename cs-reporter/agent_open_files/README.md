# Agent Open Files - QueryPie 에이전트 열린 파일 확인 도구

이 디렉토리에는 실행 중인 QueryPie 에이전트 프로세스가 현재 열고 있는 파일 목록을 확인하는 데 사용되는 스크립트가 포함되어 있습니다. 이 스크립트는 Sysinternals Suite의 `handle` 또는 `handle64` 도구를 사용하여 실제 정보를 조회합니다.

## 스크립트 목록

*   `querypie_agent_open_files.ps1`: **Windows** 환경에서 특정 프로세스(QueryPie 에이전트로 추정)가 열고 있는 파일 핸들을 `handle.exe` 또는 `handle64.exe`를 통해 조회하는 PowerShell 스크립트입니다.

## 목적

이 스크립트는 QueryPie 에이전트가 특정 파일에 대한 잠금(lock)을 유지하고 있는지, 예기치 않은 파일을 열고 있는지 등을 진단하여 에이전트 관련 문제를 해결하는 데 도움을 줄 수 있습니다.

## 주요 기능

*   실행 중인 프로세스 목록에서 'QueryPie' 또는 관련 키워드를 포함하는 프로세스를 찾습니다. (스크립트 내부 로직에 따라 다를 수 있습니다.)
*   Sysinternals의 `handle` 또는 `handle64` 도구를 실행하여 해당 프로세스가 열고 있는 파일 핸들(경로) 목록을 조회하고 결과를 필터링하여 출력합니다.

## 사전 요구 사항

*   **Windows:** PowerShell
*   **Sysinternals Handle:** Microsoft Sysinternals Suite의 `handle.exe` 또는 `handle64.exe` 파일이 필요합니다.
    *   [Sysinternals Suite 다운로드 페이지](https://learn.microsoft.com/en-us/sysinternals/downloads/handle) 에서 다운로드할 수 있습니다.
    *   다운로드 후 압축을 해제하여 `handle.exe` 또는 `handle64.exe` 파일을 준비합니다.
*   **관리자 권한:** 다른 프로세스의 정보를 조회하고 `handle` 도구를 사용하기 위해 반드시 관리자 권한으로 PowerShell을 실행해야 합니다.

## 사용 방법

**중요:** 이 스크립트는 내부적으로 `handle.exe` 또는 `handle64.exe`를 실행합니다. 따라서 **스크립트를 실행하는 PowerShell의 현재 작업 디렉토리가 `handle.exe` 또는 `handle64.exe` 파일이 있는 디렉토리여야 합니다.**

1.  **`handle` 실행 파일 준비:** `handle.exe` 또는 `handle64.exe` 파일을 다운로드하고 압축을 해제한 위치를 확인합니다.
2.  **관리자 권한으로 PowerShell 실행:** 시작 메뉴에서 PowerShell 검색 후 마우스 오른쪽 클릭 -> '관리자 권한으로 실행'을 선택합니다.
3.  **`handle` 위치로 이동:** PowerShell 창에서 `cd` 명령어를 사용하여 `handle.exe` 또는 `handle64.exe` 파일이 있는 디렉토리로 이동합니다.
    ```powershell
    cd path\to\directory\containing\handle_executable
    ```
4.  **스크립트 실행 (아래 두 가지 방법 중 선택):**

    **방법 A: 파일로 저장하여 실행 (권장)**
    *   현재 세션의 스크립트 실행 정책 변경이 필요할 수 있습니다:
        ```powershell
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
        ```
    *   스크립트 파일의 전체 경로를 지정하여 실행합니다:
        ```powershell
        # 예: 스크립트가 C:\tools\cs-reporter\agent_open_files 에 있다면
        C:\tools\cs-reporter\agent_open_files\querypie_agent_open_files.ps1
        ```
        *(참고: 스크립트에 따라 에이전트 프로세스 이름이나 ID를 파라미터로 전달해야 할 수도 있습니다.)*

    **방법 B: 스크립트 내용 복사 및 붙여넣기로 실행**
    *   `querypie_agent_open_files.ps1` 파일의 **전체 내용**을 복사합니다.
    *   **관리자 권한으로 실행 중이고, `handle` 실행 파일이 있는 디렉토리로 이동한** PowerShell 창에 복사한 내용을 **붙여넣기** 합니다.
    *   **Enter** 키를 누릅니다. 스크립트가 즉시 실행됩니다. (이 스크립트는 일반적으로 별도 파라미터 입력을 요구하지 않을 수 있습니다.)

## 결과 확인

스크립트는 `handle` 도구의 출력을 바탕으로 QueryPie 에이전트 프로세스가 열고 있는 파일들의 전체 경로 목록을 출력합니다. 출력 내용이 없거나 오류가 발생하면 에이전트가 실행 중이지 않거나, 스크립트 실행 권한(관리자 권한)이 부족하거나, `handle` 실행 파일을 찾을 수 없거나(잘못된 위치에서 실행), 스크립트 내부에서 프로세스를 찾는 로직이 현재 환경과 맞지 않을 수 있습니다.

## 사용 사례

*   에이전트가 특정 파일을 삭제하거나 수정하지 못하게 막고 있는지 확인할 때.
*   에이전트가 예상치 못한 파일을 사용하고 있는지 확인할 때.
*   에이전트 충돌 또는 성능 문제의 원인을 조사할 때 파일 접근 패턴을 확인할 때. 