<#
.SYNOPSIS
  지정된 호스트와 포트로의 TCP 네트워크 연결을 90초 타임아웃으로 20회 반복 테스트하며, 각 시도에 걸린 시간을 출력합니다.
.DESCRIPTION
  이 스크립트는 System.Net.Sockets.TcpClient를 사용하여 대상 호스트와 포트에 대한
  TCP 연결 시도를 1초 간격으로 20회 반복하고, 각 시도마다 최대 90초의 연결 타임아웃을 적용합니다.
  각 연결 시도에 소요된 시간도 함께 출력됩니다.
  간헐적인 연결 문제나 긴 타임아웃이 필요한 환경에서의 안정성 테스트에 유용합니다.
.PARAMETER TargetHost
  연결을 테스트할 대상 호스트의 이름 또는 IP 주소입니다. (필수)
.PARAMETER TargetPort
  연결을 테스트할 대상 TCP 포트 번호입니다. (필수)
.EXAMPLE
  .\conn_checker.ps1 -TargetHost querypie-proxy.example.com -TargetPort 9000
  # querypie-proxy.example.com의 9000번 포트로 1초 간격, 90초 타임아웃, 20회 연결 테스트하며 각 시도 시간을 출력합니다.
.EXAMPLE
  .\conn_checker.ps1 192.168.1.100 3306
  # 192.168.1.100의 3306번 포트로 1초 간격, 90초 타임아웃, 20회 연결 테스트하며 각 시도 시간을 출력합니다.
.NOTES
  이 스크립트는 .NET Framework의 System.Net.Sockets.TcpClient를 사용합니다.
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
        [System.ConsoleColor]$Color,
        [switch]$NoNewline
    )
    $CurrentColor = [System.Console]::ForegroundColor
    [System.Console]::ForegroundColor = $Color
    if ($NoNewline) {
        Write-Host $Message -NoNewline
    } else {
        Write-Host $Message
    }
    [System.Console]::ForegroundColor = $CurrentColor
}

$maxAttempts = 20
$sleepIntervalSeconds = 1
$connectionTimeoutMilliseconds = 90 * 1000 # 90 seconds
$successfulAttempts = 0
$failedAttempts = 0
$totalElapsedTime = New-TimeSpan # 총 소요 시간 측정을 위해 초기화

Write-ColorHost "TCP 연결 반복 테스트 시작: 호스트 '$TargetHost', 포트 '$TargetPort'" $BlueColor
Write-ColorHost "총 시도 횟수: $maxAttempts, 시도 간 간격: ${sleepIntervalSeconds}초, 연결 타임아웃: $($connectionTimeoutMilliseconds/1000)초" $BlueColor
Write-Host "--------------------------------------------------"

for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    Write-ColorHost "시도 [$attempt/$maxAttempts]: " $BlueColor -NoNewline
    Write-Host -NoNewline "호스트 '$TargetHost' 포트 '$TargetPort' 연결 중 (최대 $($connectionTimeoutMilliseconds/1000)초)... "

    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connectionSuccess = $false
    $errorMessage = ""
    
    $attemptStartTime = Get-Date # 현재 시도 시작 시간 기록

    try {
        $connectTask = $tcpClient.ConnectAsync($TargetHost, $TargetPort)
        if ($connectTask.Wait($connectionTimeoutMilliseconds)) {
            # Task completed within timeout
            if ($connectTask.IsFaulted) {
                # Connection failed with an exception
                $errorMessage = $connectTask.Exception.GetBaseException().Message
            } elseif ($tcpClient.Connected) {
                $connectionSuccess = $true
            } else {
                # Task completed, not faulted, but not connected
                $errorMessage = "연결 시도 완료, 그러나 연결되지 않음"
            }
        } else {
            # Timeout occurred
            $errorMessage = "타임아웃 ($($connectionTimeoutMilliseconds/1000)초)"
            # Close the client to abort the potentially ongoing connection attempt
            $tcpClient.Close() 
        }
    } catch [System.AggregateException] {
        $errorMessage = $_.Exception.InnerExceptions[0].GetBaseException().Message
    } catch {
        $errorMessage = $_.Exception.GetBaseException().Message
    } finally {
        if ($tcpClient) {
            $tcpClient.Dispose() 
        }
    }
    
    $attemptEndTime = Get-Date # 현재 시도 종료 시간 기록
    $duration = New-TimeSpan -Start $attemptStartTime -End $attemptEndTime
    $totalElapsedTime = $totalElapsedTime.Add($duration)

    if ($connectionSuccess) {
        Write-ColorHost "성공! (소요 시간: $($duration.TotalSeconds.ToString("F3"))초)" $GreenColor
        $successfulAttempts++
    } else {
        Write-ColorHost "실패. ($errorMessage) (소요 시간: $($duration.TotalSeconds.ToString("F3"))초)" $RedColor
        $failedAttempts++
    }

    if ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds $sleepIntervalSeconds
    }
}

Write-Host "--------------------------------------------------"
Write-ColorHost "테스트 완료. 요약:" $BlueColor
Write-Host "총 시도: $maxAttempts"
Write-ColorHost "  성공: $successfulAttempts" $GreenColor
Write-ColorHost "  실패: $failedAttempts" $RedColor
Write-Host "총 누적 연결 시도 시간 (대기 시간 제외): $($totalElapsedTime.TotalSeconds.ToString("F3"))초"
Write-Host "--------------------------------------------------"

if ($failedAttempts -gt 0) {
    Write-ColorHost "하나 이상의 연결 시도에 실패했습니다. 로그된 오류 메시지를 확인하세요." $YellowColor
    Write-ColorHost "일반적인 실패 원인:" $YellowColor
    Write-ColorHost "- 대상 호스트가 응답하지 않음 (오프라인, 존재하지 않는 호스트)" $YellowColor
    Write-ColorHost "- 방화벽이 해당 포트로의 연결을 차단함 (로컬 또는 원격)" $YellowColor
    Write-ColorHost "- 대상 포트에서 서비스가 리스닝하고 있지 않음" $YellowColor
    Write-ColorHost "- 간헐적인 네트워크 경로 문제 (라우팅, DNS 등)" $YellowColor
    Write-ColorHost "- 지정된 타임아웃 내에 연결을 설정할 수 없음" $YellowColor
}

[System.Console]::ForegroundColor = $NoColor 