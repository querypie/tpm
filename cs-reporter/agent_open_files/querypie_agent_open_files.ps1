#Requires -RunAsAdministrator # Handle64.exe는 관리자 권한이 필요할 수 있습니다.

<#
.SYNOPSIS
특정 프로세스가 열고 있는 파일/디렉토리 핸들을 Handle64.exe를 사용하여 목록화하고,
그 중 'logs' 문자열을 포함하는 경로를 별도로 표시합니다. (64비트 전용)

.DESCRIPTION
이 스크립트는 현재 디렉토리에 있는 Handle64.exe를 사용하여
'QueryPieAgent.Desktop.Windows' 프로세스가 열고 있는 모든 파일 및 디렉토리 핸들을 출력합니다.
그 후, 전체 목록에서 경로에 'logs' 문자열(대소문자 구분 없음)을 포함하는 항목만 필터링하여 다시 출력합니다.
만약 현재 디렉토리에 Handle64.exe 실행 파일이 없으면, 다운로드 링크를 안내하고 종료합니다.

.NOTES
- 관리자 권한으로 PowerShell을 실행해야 합니다.
- Handle64.exe 파일이 스크립트와 동일한 디렉토리에 있거나, 없을 경우 다운로드 안내가 나옵니다.
- 대상 프로세스 'QueryPieAgent.Desktop.Windows'가 실행 중이어야 합니다.
- 이 스크립트는 64비트 Windows 환경 및 Handle64.exe 사용을 가정합니다.
#>

# --- 설정 ---
$processName = "QueryPieAgent.Desktop.Windows"

# --- Handle64.exe 실행 파일 확인 및 경로 설정 (64비트 전용) ---
$handleExePath = ".\handle64.exe" # 64비트 버전 경로

if (Test-Path $handleExePath) {
    Write-Host "[정보] 사용할 Handle 실행 파일: $handleExePath" -ForegroundColor Green
} else {
    # handle64.exe가 현재 디렉토리에 없는 경우
    Write-Error "현재 디렉토리에서 '$handleExePath'를 찾을 수 없습니다."
    Write-Warning "Handle 유틸리티는 Microsoft Sysinternals Suite의 일부이며 별도로 다운로드해야 합니다."
    Write-Host "다운로드 링크: https://learn.microsoft.com/ko-kr/sysinternals/downloads/handle"
    Write-Host "위 링크에서 Handle.zip 파일을 다운로드하고 압축을 해제한 후,"
    # $PSScriptRoot는 스크립트 파일이 저장된 디렉토리를 의미합니다.
    # PowerShell 콘솔에서 직접 코드를 실행하는 경우 $PSScriptRoot가 비어있을 수 있으므로, pwd (현재 디렉토리) 사용도 고려할 수 있습니다.
    # 여기서는 스크립트 파일로 저장하여 사용하는 것을 가정합니다.
    Write-Host "'handle64.exe' 파일을 이 스크립트가 있는 디렉토리( $PSScriptRoot )에 복사해주세요."
    Read-Host "준비가 완료되면 Enter 키를 눌러 종료하고 스크립트를 다시 실행하세요..."
    exit # 스크립트 실행 중단
}

$handleExePath = (Resolve-Path -Path $handleExePath -ErrorAction Stop).Path

# --- 관리자 권한 확인 (선택 사항, #Requires 사용 권장) ---
$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Warning "이 스크립트는 관리자 권한으로 실행해야 할 수 있습니다. 결과가 제대로 나오지 않으면 관리자 권한으로 PowerShell을 다시 시작하고 실행해주세요."
    # 필요한 경우 여기서 실행 중단: return 또는 exit
}

# --- 대상 프로세스 찾기 ---
Write-Host "[정보] '$processName' 프로세스를 찾는 중..."
$processes = Get-Process -Name $processName -ErrorAction SilentlyContinue

if ($processes.Count -eq 0) {
    Write-Error "'$processName' 프로세스가 실행 중이지 않습니다. 프로세스를 시작하고 다시 시도하세요."
    Read-Host "계속하려면 Enter 키를 누르십시오..."
    exit
} elseif ($processes.Count -gt 1) {
    Write-Warning "'$processName' 프로세스가 여러 개 실행 중입니다. 첫 번째로 찾은 프로세스(PID: $($processes[0].Id))를 대상으로 진행합니다."
    $targetProcess = $processes[0]
} else {
    $targetProcess = $processes
    Write-Host "[정보] '$($targetProcess.Name)' 프로세스를 찾았습니다 (PID: $($targetProcess.Id))." -ForegroundColor Green
}

$targetPid = $targetProcess.Id

# --- Handle64.exe 실행 및 출력 캡처 ---
# $handleExePath 변수에 handle64.exe 경로가 담겨 있음
Write-Host "[정보] PID $targetPid 에 대한 핸들 정보를 '$handleExePath'를 사용하여 가져오는 중..."
try {
    # ProcessStartInfo를 사용하여 표준 출력 인코딩을 명시적으로 설정 (한글 경로 등 깨짐 방지)
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $handleExePath # handle64.exe 경로 사용
    # -accepteula: 라이선스 동의 창 방지, -nobanner: 로고 숨김, -p <PID>: 대상 프로세스 지정
    $processInfo.Arguments = "-accepteula -nobanner -p $targetPid"
    $processInfo.RedirectStandardOutput = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null

    # 표준 출력 결과 읽기
    $handleOutput = $process.StandardOutput.ReadToEnd()

    # 프로세스가 완료될 때까지 기다림
    $process.WaitForExit()

    # Handle64.exe 실행 결과 확인 (종료 코드 0이 정상이 아닐 수도 있음, 오류 메시지 유무도 중요)
    if ($process.ExitCode -ne 0) {
         Write-Warning "Handle 실행이 비정상적으로 종료되었을 수 있습니다 (종료 코드: $($process.ExitCode)). 결과가 정확하지 않을 수 있습니다. 관리자 권한으로 실행했는지 확인하세요."
    }
    # 오류 메시지가 출력에 포함되었는지 간단히 확인
    if ($handleOutput -match "Unable to obtain") {
        Write-Warning "Handle 출력에 오류 메시지가 포함되어 있습니다. 관리자 권한이 필요할 수 있습니다."
    }

} catch {
    Write-Error "Handle 실행 중 오류 발생: $($_.Exception.Message)"
    Read-Host "계속하려면 Enter 키를 누르십시오..."
    exit
}

# --- 출력 1: Handle.exe 전체 결과 출력 ---
Write-Host "`n--------------------------------------------------"
Write-Host "[$($targetProcess.Name) (PID: $targetPid)] Handle.exe 전체 출력 결과" -ForegroundColor Cyan
Write-Host "--------------------------------------------------"
if ($handleOutput) {
    # 캡처된 전체 출력을 그대로 출력
    Write-Host $handleOutput
} else {
    Write-Host "[정보] Handle.exe에서 출력을 받지 못했습니다." -ForegroundColor Yellow
}

# --- 출력 2: 'logs' 포함 라인 필터링 및 출력 ---
Write-Host "`n--------------------------------------------------"
Write-Host "[$($targetProcess.Name) (PID: $targetPid)] 전체 출력 중 'logs' 포함 라인" -ForegroundColor Cyan
Write-Host "--------------------------------------------------"
if ($handleOutput) {
    # 전체 출력을 줄 단위로 분리하고 'logs' 문자열을 포함하는 라인 필터링
    # -split `r?`n : Windows(CRLF) 및 Unix(LF) 줄바꿈 모두 처리
    $logLines = $handleOutput -split '\r?\n' | Where-Object { $_ -match 'logs' } # -match는 기본적으로 대소문자 구분 안 함

    if ($logLines) {
        # 필터링된 라인들을 그대로 출력
        $logLines | ForEach-Object { Write-Host $_ }
        Write-Host "`n[정보] 'logs'를 포함하는 $($logLines.Count)개의 라인을 찾았습니다." -ForegroundColor Green
    } else {
        Write-Host "[정보] 'logs' 문자열을 포함하는 라인을 찾지 못했습니다." -ForegroundColor Yellow
    }
} else {
     Write-Host "[정보] 필터링할 Handle.exe 출력이 없습니다." -ForegroundColor Yellow
}

Write-Host "`n스크립트 실행 완료."
# (선택 사항)
# Read-Host "결과를 확인 후 Enter 키를 누르면 종료됩니다..."
