<#
.SYNOPSIS
  지정된 호스트와 포트로의 TCP 네트워크 연결을 테스트합니다.
.DESCRIPTION
  이 스크립트는 Test-NetConnection cmdlet을 사용하여 대상 호스트와 포트에 대한
  TCP 연결 시도 결과를 보여줍니다. 방화벽 규칙이나 서비스 리스닝 상태를
  간단히 점검하는 데 유용합니다.
.PARAMETER TargetHost
  연결을 테스트할 대상 호스트의 이름 또는 IP 주소입니다. (필수)
.PARAMETER TargetPort
  연결을 테스트할 대상 TCP 포트 번호입니다. (필수)
.EXAMPLE
  .\conn_checker.ps1 -TargetHost querypie-proxy.example.com -TargetPort 9000
  # querypie-proxy.example.com의 9000번 포트로 연결을 테스트합니다.
.EXAMPLE
  .\conn_checker.ps1 192.168.1.100 3306
  # 192.168.1.100의 3306번 포트로 연결을 테스트합니다. (위치 기반 파라미터)
.NOTES
  Test-NetConnection cmdlet은 PowerShell 4.0 이상에서 사용할 수 있습니다.
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$TargetHost,

    [Parameter(Mandatory=$true, Position=1)]
    [int]$TargetPort
)

# 색상 정의
$BlueColor = [System.ConsoleColor]::Blue
$GreenColor = [System.ConsoleColor]::Green
$RedColor = [System.ConsoleColor]::Red
$YellowColor = [System.ConsoleColor]::Yellow
$NoColor = [System.Console]::ForegroundColor

Function Write-ColorHost {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [System.ConsoleColor]$Color
    )
    $CurrentColor = [System.Console]::ForegroundColor
    [System.Console]::ForegroundColor = $Color
    Write-Host $Message
    [System.Console]::ForegroundColor = $CurrentColor
}

Write-ColorHost "TCP 연결 테스트 시작: 호스트 '$TargetHost', 포트 '$TargetPort'" $BlueColor
Write-Host "명령어 실행: Test-NetConnection -ComputerName $TargetHost -Port $TargetPort"
Write-Host "--------------------------------------------------"

$connectionResult = Test-NetConnection -ComputerName $TargetHost -Port $TargetPort -InformationLevel Quiet -ErrorAction SilentlyContinue

if ($connectionResult) {
    Write-ColorHost "결과: 연결 성공!" $GreenColor
    Write-Host "--------------------------------------------------"
    # 상세 정보 표시 (선택 사항)
    Test-NetConnection -ComputerName $TargetHost -Port $TargetPort | Format-List *
} else {
    Write-ColorHost "결과: 연결 실패." $RedColor
    Write-Host "--------------------------------------------------"
    Write-ColorHost "가능한 원인:" $YellowColor
    Write-ColorHost "- 대상 호스트가 응답하지 않음 (오프라인, 존재하지 않는 호스트)" $YellowColor
    Write-ColorHost "- 방화벽이 해당 포트로의 연결을 차단함 (로컬 또는 원격)" $YellowColor
    Write-ColorHost "- 대상 포트에서 서비스가 리스닝하고 있지 않음" $YellowColor
    Write-ColorHost "- 네트워크 경로 문제 (라우팅, DNS 등)" $YellowColor
    Write-Host "--------------------------------------------------"
    Write-ColorHost "상세 오류 정보 확인을 위해 다음 명령어를 직접 실행해 보세요:" $BlueColor
    Write-Host "Test-NetConnection -ComputerName $TargetHost -Port $TargetPort"
}

[System.Console]::ForegroundColor = $NoColor 