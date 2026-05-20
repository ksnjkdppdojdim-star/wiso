#Requires -Version 5.1
# Fonctions communes : version, encodage console, erreurs, execution native.

$script:WisoVersion = "0.5.0"

function Get-WisoVersion {
    return $script:WisoVersion
}

function Get-WisoReservedWords {
    return @(
        "help", "-h", "--help", "profiles", "list", "wifi", "wlan", "radio", "show", "key", "pw", "password",
        "export", "keys", "delete", "force", "json", "raw", "interfaces", "if", "neighbors", "arp", "brief",
        "ping", "port", "scan", "quick", "portscan", "route", "dns", "gateway", "gw", "lan", "parallel",
        "firewall", "fw", "listeners", "listen", "shares", "share", "nmap", "who", "version", "ver"
    )
}

function Test-WisoReservedWord {
    param([string]$Word)
    if ($null -eq $Word) { return $false }
    $w = $Word.Trim().ToLowerInvariant()
    return (Get-WisoReservedWords) -contains $w
}

function New-WisoUsageError {
    param([string]$Message)
    return [System.Management.Automation.RuntimeException]::new("wiso usage: $Message")
}

function Invoke-WisoWithErrorContext {
    param(
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )
    try {
        & $Action
    } catch {
        $inner = $_.Exception.Message
        throw [System.Management.Automation.RuntimeException]::new(
            "wiso [$Branch] $inner",
            $_.Exception
        )
    }
}

function Get-WisoInstallRoot {
    if ($global:WisoInstallRoot) { return $global:WisoInstallRoot }
    return $PSScriptRoot
}

function Convert-WisoConsoleText {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $fixed = $Text
    $fixed = $fixed -replace 'Interface\S*\s*:', 'Interface:'
    $fixed = $fixed -replace "Adresse Internet", "Address"
    $fixed = $fixed -replace "Adresse physique", "MAC"
    $fixed = $fixed -replace "dynamique", "dynamic"
    $fixed = $fixed -replace "statique", "static"
    $fixed = $fixed -replace "Type", "Type"
    return $fixed
}

function Invoke-WisoNativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [string]$Arguments = "",
        [int]$WaitMs = 8000,
        [switch]$FixConsoleEncoding
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FileName
    $psi.Arguments = $Arguments
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    if ($FixConsoleEncoding) {
        try {
            $oem = [System.Text.Encoding]::GetEncoding(850)
            $psi.StandardOutputEncoding = $oem
            $psi.StandardErrorEncoding = $oem
        } catch {
            # anciennes versions .NET : normalisation textuelle seulement
        }
    }
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $null = $p.WaitForExit($WaitMs)
    if ($FixConsoleEncoding) {
        $out = Convert-WisoConsoleText -Text $out
        $err = Convert-WisoConsoleText -Text $err
    }
    if (-not [string]::IsNullOrWhiteSpace($err)) {
        $out = $out + "`n" + $err
    }
    return $out
}
