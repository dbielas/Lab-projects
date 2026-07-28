<#
.SYNOPSIS
    Idempotent Schannel Transport Hardening Script for Windows Server 2025.
    Creates missing registry keys and enforces TLS 1.2 / TLS 1.3 defaults.
#>

# Define target Schannel protocol paths
$SchannelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"

$ProtocolsToDisable = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1")
$ProtocolsToEnable  = @("TLS 1.2", "TLS 1.3")

# 1. Build and Disable Insecure Protocols
foreach ($proto in $ProtocolsToDisable) {
    foreach ($side in @("Client", "Server")) {
        $path = "$SchannelPath\$proto\$side"
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
        Set-ItemProperty -Path $path -Name "Enabled" -Value 0 -Type DWord
        Set-ItemProperty -Path $path -Name "DisabledByDefault" -Value 1 -Type DWord
    }
    Write-Host "[+] Disabled $proto" -ForegroundColor Red
}

# 2. Build and Enable Secure Protocols (TLS 1.2 & TLS 1.3)
foreach ($proto in $ProtocolsToEnable) {
    foreach ($side in @("Client", "Server")) {
        $path = "$SchannelPath\$proto\$side"
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
        Set-ItemProperty -Path $path -Name "Enabled" -Value 1 -Type DWord
        Set-ItemProperty -Path $path -Name "DisabledByDefault" -Value 0 -Type DWord
    }
    Write-Host "[+] Enforced $proto" -ForegroundColor Green
}

# 3. Enforce .NET 4.0 Strong Cryptography (For MSAL Engine)
$NetKeys = @(
    'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319',
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NetFramework\v4.0.30319'
)
foreach ($key in $NetKeys) {
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name 'SchUseStrongCrypto' -Value 1 -Type DWord
    Set-ItemProperty -Path $key -Name 'SystemDefaultTlsVersions' -Value 1 -Type DWord
}
Write-Host "[+] Enforced .NET Strong Cryptography" -ForegroundColor Green