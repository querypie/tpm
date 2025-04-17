<#
.SYNOPSIS
  네트워크 진단 스크립트 (Windows PowerShell 버전)
.DESCRIPTION
  Web Domain과 Host Domain을 입력받아 프록시 설정, DNS 조회, URL 접근, 파일 다운로드 시간 측정, TLS 인증서 확인 등
  네트워크 관련 진단 작업을 수행합니다.
.PARAMETER WebDomainInput
  확인할 웹 도메인 또는 URL (예: example.com 또는 https://example.com)
.PARAMETER HostDomain
  확인할 호스트 도메인 (예: api.example.com)
.EXAMPLE
  .\agent-diag-win.ps1 www.google.com google.com
.EXAMPLE
  .\agent-diag-win.ps1 https://www.google.com google.com
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$WebDomainInput,

    [Parameter(Mandatory=$true)]
    [string]$HostDomain
)

# --- 초기 설정 ---
# 색상 정의 (가독성 향상)
$BlueColor = [System.ConsoleColor]::Blue
$GreenColor = [System.ConsoleColor]::Green
$YellowColor = [System.ConsoleColor]::Yellow
$RedColor = [System.ConsoleColor]::Red
$NoColor = [System.Console]::ForegroundColor # 현재 전경색 저장 (초기화용)

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

# 스키마 감지 및 도메인 분리
$WebScheme = "https://" # 기본값
if ($WebDomainInput -match '^https://') {
    $WebScheme = "https://"
} elseif ($WebDomainInput -match '^http://') {
    $WebScheme = "http://"
}
# 정규 표현식을 사용하여 스키마 제거
$WebDomain = $WebDomainInput -replace '^https?://'

Write-ColorHost "스크립트를 시작합니다. 입력된 도메인:" $BlueColor
Write-Host "Web Domain Input: $WebDomainInput"
Write-Host "Detected Scheme: $WebScheme"
Write-Host "Processed Web Domain: $WebDomain"
Write-Host "Host Domain: $HostDomain"
Write-Host "========================================"
Write-Host ""

# --- 0. 프록시 설정 확인 ---
Write-ColorHost "[0. 프록시 설정 확인]" $BlueColor
$proxyFound = $false
$proxyVars = @("http_proxy", "https_proxy", "ftp_proxy", "all_proxy", "HTTP_PROXY", "HTTPS_PROXY", "FTP_PROXY", "ALL_PROXY")
foreach ($varName in $proxyVars) {
    $varValue = Get-Variable -Name "env:$varName" -ErrorAction SilentlyContinue
    if ($varValue) {
        Write-Host "  " -NoNewline
        Write-ColorHost "$varName" $YellowColor -NoNewline
        Write-Host ": $($varValue.Value)"
        $proxyFound = $true
    }
}
$noProxyVars = @("no_proxy", "NO_PROXY")
$noProxyFound = $false
foreach ($varName in $noProxyVars) {
    $varValue = Get-Variable -Name "env:$varName" -ErrorAction SilentlyContinue
    if ($varValue) {
        Write-Host "  " -NoNewline
        Write-ColorHost "$varName" $YellowColor -NoNewline
        Write-Host ": $($varValue.Value)"
        $noProxyFound = $true
    }
}

if (-not $proxyFound -and -not $noProxyFound) {
    Write-ColorHost "  => 설정된 프록시 관련 환경 변수가 없습니다." $GreenColor
} elseif (-not $proxyFound) {
    Write-ColorHost "  => 직접적인 프록시 설정은 없지만, no_proxy 설정은 존재합니다." $GreenColor
} else {
    Write-ColorHost "  => 하나 이상의 프록시 관련 환경 변수가 설정되어 있습니다." $YellowColor
}
Write-Host "========================================"
Write-Host ""

# --- 1. web_domain IP 목록 출력 (Resolve-DnsName 사용) ---
Write-ColorHost "[1. $WebDomain IP 주소 확인 (Resolve-DnsName)]" $BlueColor
Write-Host "명령어: Resolve-DnsName -Name $WebDomain -Type A"
try {
    $dnsResult = Resolve-DnsName -Name $WebDomain -Type A -ErrorAction Stop
    # IPv4 주소만 필터링하여 출력
    $ipAddresses = $dnsResult | Where-Object { $_.IPAddress -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -ExpandProperty IPAddress
    if ($ipAddresses) {
        Write-ColorHost ($ipAddresses -join "`n") $GreenColor
    } else {
        Write-ColorHost "  => A 레코드를 찾을 수 없습니다." $RedColor
    }
} catch {
    Write-ColorHost "  => DNS 조회 중 오류 발생: $($_.Exception.Message)" $RedColor
}
Write-Host "========================================"
Write-Host ""

# --- 2. {WebScheme}{WebDomain}/version 내용 확인 (Invoke-WebRequest 사용) ---
$VersionUrl = "$WebScheme$WebDomain/version"
Write-ColorHost "[2. $VersionUrl 내용 확인 (Invoke-WebRequest)]" $BlueColor
Write-Host "명령어: Invoke-WebRequest -Uri $VersionUrl"
try {
    # `-UseBasicParsing`은 IE 엔진 의존성을 제거합니다 (PowerShell Core에서는 불필요).
    # 필요에 따라 `-SkipCertificateCheck` 등을 추가할 수 있습니다.
    $response = Invoke-WebRequest -Uri $VersionUrl -UseBasicParsing -ErrorAction Stop
    Write-Host "--- Status Code ---"
    Write-ColorHost $response.StatusCode $GreenColor
    Write-Host "--- Headers ---"
    Write-Host ($response.Headers | Out-String)
    Write-Host "--- Content ---"
    Write-Host $response.Content
} catch {
    Write-ColorHost "  => URL 요청 중 오류 발생: $($_.Exception.Message)" $RedColor
    # 상세 오류 정보 (예: 상태 코드)
    if ($_.Exception.Response) {
        Write-Host "  Status Code: $($_.Exception.Response.StatusCode.value__)"
        Write-Host "  Status Description: $($_.Exception.Response.StatusDescription)"
    }
}
Write-Host "========================================"
Write-Host ""

# --- 3. DMG 다운로드 디버그 정보 및 시간 측정 ---
# 참고: PowerShell의 Invoke-WebRequest는 curl -v와 동일한 수준의 상세 디버그 정보를 직접 제공하지 않습니다.
#       오류 발생 시 예외 메시지를 확인하거나, Fiddler와 같은 외부 도구를 사용해야 할 수 있습니다.
#       여기서는 다운로드 자체와 시간 측정에 집중합니다.
$DmgUrl = "$WebScheme$WebDomain/agent/osx/arm64/QueryPieAgent.dmg"
Write-ColorHost "[3. $DmgUrl 다운로드 시간 측정]" $BlueColor
Write-Host "명령어: Measure-Command { Invoke-WebRequest -Uri $DmgUrl -OutFile `$null -UseBasicParsing }"
try {
    $downloadTime = Measure-Command {
        # 파일을 저장하지 않고 다운로드만 수행 (`-OutFile $null`)
        Invoke-WebRequest -Uri $DmgUrl -OutFile $null -UseBasicParsing -ErrorAction Stop
    }
    Write-ColorHost "다운로드 총 소요 시간: $($downloadTime.TotalSeconds) 초" $GreenColor
} catch {
    Write-ColorHost "  => DMG 다운로드 중 오류 발생: $($_.Exception.Message)" $RedColor
    if ($_.Exception.Response) {
        Write-Host "  Status Code: $($_.Exception.Response.StatusCode.value__)"
        Write-Host "  Status Description: $($_.Exception.Response.StatusDescription)"
    }
}
Write-Host "========================================"
Write-Host ""

# --- 4. host_domain IP 목록 출력 (Resolve-DnsName 사용) ---
Write-ColorHost "[4. $HostDomain IP 주소 확인 (Resolve-DnsName)]" $BlueColor
Write-Host "명령어: Resolve-DnsName -Name $HostDomain -Type A"
try {
    $dnsResultHost = Resolve-DnsName -Name $HostDomain -Type A -ErrorAction Stop
    $ipAddressesHost = $dnsResultHost | Where-Object { $_.IPAddress -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -ExpandProperty IPAddress
    if ($ipAddressesHost) {
        Write-ColorHost ($ipAddressesHost -join "`n") $GreenColor
    } else {
        Write-ColorHost "  => A 레코드를 찾을 수 없습니다." $RedColor
    }
} catch {
    Write-ColorHost "  => DNS 조회 중 오류 발생: $($_.Exception.Message)" $RedColor
}
Write-Host "========================================"
Write-Host ""

# --- 5. host_domain:9000 TLS 인증서 정보 확인 ---
$HostPort = "$HostDomain:9000"
Write-ColorHost "[5. $HostPort TLS 인증서 정보 확인 (.NET SslStream)]" $BlueColor
Write-Host "도메인 $HostDomain, 포트 9000 에 대한 TLS 연결 시도..."

$tcpClient = $null
$sslStream = $null
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    # 연결 시도 (타임아웃 추가 가능)
    $connectTask = $tcpClient.ConnectAsync($HostDomain, 9000)
    if (-not $connectTask.Wait(5000)) { # 5초 타임아웃
        throw "Connection timed out."
    }

    if ($tcpClient.Connected) {
        Write-Host "TCP 연결 성공. TLS 핸드셰이크 시도..."
        # TLS 스트림 생성 및 인증 시도
        # ServerCertificateValidationCallback을 사용하여 모든 인증서를 수락 (정보 확인 목적)
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true }, $null) # 마지막 인자($null)는 ClientCertificateSelectionCallback

        # 클라이언트 인증서 없이 서버 인증 (SNI를 위해 호스트 이름 전달)
        $sslStream.AuthenticateAsClient($HostDomain)

        if ($sslStream.IsAuthenticated) {
            Write-ColorHost "TLS 핸드셰이크 성공." $GreenColor
            $remoteCert = $sslStream.RemoteCertificate
            if ($remoteCert) {
                Write-ColorHost "--- 서버 인증서 정보 ---" $GreenColor
                # X509Certificate2 객체를 사용하면 더 많은 속성 접근 가능
                $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($remoteCert)
                Write-Host "Subject: $($cert2.Subject)"
                Write-Host "Issuer: $($cert2.Issuer)"
                Write-Host "Version: $($cert2.Version)"
                Write-Host "Valid From: $($cert2.NotBefore)"
                Write-Host "Valid To: $($cert2.NotAfter)"
                Write-Host "Thumbprint: $($cert2.Thumbprint)"
                Write-Host "Serial Number: $($cert2.SerialNumber)"
                # 전체 인증서 정보 (PEM 형식 유사)
                # Write-Host "-----BEGIN CERTIFICATE-----"
                # Write-Host $([System.Convert]::ToBase64String($cert2.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert), [System.Base64FormattingOptions]::InsertLineBreaks))
                # Write-Host "-----END CERTIFICATE-----"
            } else {
                Write-ColorHost "서버로부터 인증서를 받지 못했습니다." $YellowColor
            }
        } else {
            Write-ColorHost "TLS 핸드셰이크 실패." $RedColor
        }
    } else {
        Write-ColorHost "TCP 연결 실패." $RedColor
    }
} catch {
    Write-ColorHost "  => $HostPort 연결 또는 인증서 확인 중 오류 발생:" $RedColor
    Write-ColorHost "     $($_.Exception.Message)" $RedColor
    # InnerException이 있는 경우 함께 출력
    if ($_.Exception.InnerException) {
        Write-ColorHost "     Inner Exception: $($_.Exception.InnerException.Message)" $RedColor
    }
} finally {
    # 리소스 정리
    if ($sslStream -ne $null) {
        $sslStream.Dispose()
    }
    if ($tcpClient -ne $null) {
        $tcpClient.Dispose()
    }
}
Write-Host "========================================"
Write-Host ""

Write-ColorHost "스크립트 실행 완료." $BlueColor
# 원래 콘솔 색상으로 복원
[System.Console]::ForegroundColor = $NoColor 