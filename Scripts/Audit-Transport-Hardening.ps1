<#
.SYNOPSIS
    Audits .NET Strong Cryptography and Schannel TLS Registry States.
.NOTES
    Target Host: ENTRA-SYNC01 (10.0.2.5)
#>

[CmdletBinding()]
param()

Write-Output "=================================================================="
Write-Output " SCHANNEL & .NET TRANSPORT SECURITY AUDIT: ENTRA-SYNC01 (10.0.2.5)"
Write-Output " Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
Write-Output "=================================================================="
Write-Output ""

# 1. Audit .NET Framework Keys
Write-Output "[1] .NET Framework Strong Cryptography Keys:"
$NetKeys = @(
    'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319',
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NetFramework\v4.0.30319'
)

$DotNetResults = foreach ($key in $NetKeys) {
    if (Test-Path $key) {
        $props = Get-ItemProperty -Path $key
        [PSCustomObject]@{
            Architecture             = if ($key -like "*Wow6432Node*") { "32-bit (WOW64)" } else { "64-bit (Native)" }
            SchUseStrongCrypto       = $props.SchUseStrongCrypto
            SystemDefaultTlsVersions = $props.SystemDefaultTlsVersions
        }
    }
}
$DotNetResults | Out-String | Write-Output

# 2. Audit OS Schannel Protocol Lockdowns
Write-Output "[2] OS Schannel Protocol State:"
$SchannelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"
$AllProtocols = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1", "TLS 1.2", "TLS 1.3")

$SchannelResults = foreach ($proto in $AllProtocols) {
    foreach ($side in @("Client", "Server")) {
        $targetPath = "$SchannelPath\$proto\$side"
        if (Test-Path $targetPath) {
            $prop = Get-ItemProperty -Path $targetPath
            [PSCustomObject]@{
                Protocol          = $proto
                Role              = $side
                Enabled           = $prop.Enabled
                DisabledByDefault = $prop.DisabledByDefault
            }
        }
    }
}
$SchannelResults | Out-String | Write-Output