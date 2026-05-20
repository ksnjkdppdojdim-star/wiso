#Requires -Version 5.1
<#
.SYNOPSIS
  wiso — point d'entrée plugin Trish. Charge les modules sous .\modules puis délègue à Invoke-WisoDispatch.
#>

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PluginArgs
)

$ErrorActionPreference = "Stop"

$global:WisoInstallRoot = $PSScriptRoot

$moduleFiles = @(
    "Wiso.Common.ps1",
    "Wiso.Help.ps1",
    "Wiso.Wlan.ps1",
    "Wiso.Network.ps1",
    "Wiso.Nmap.ps1",
    "Wiso.Security.ps1",
    "Wiso.Machine.ps1",
    "Wiso.Json.ps1",
    "Wiso.Dispatch.ps1"
)

$modulesDir = Join-Path -Path $script:WisoInstallRoot -ChildPath "modules"
foreach ($name in $moduleFiles) {
    $path = Join-Path -Path $modulesDir -ChildPath $name
    if (-not (Test-Path -LiteralPath $path)) {
        throw "wiso: module manquant: $path"
    }
    . $path
}

try {
    $safeArgs = @()
    if ($null -ne $PluginArgs) { $safeArgs = @($PluginArgs) }
    $output = Invoke-WisoDispatch -PluginArgs $safeArgs
    if ($null -ne $output -and $output.Length -gt 0) {
        Write-Output $output
    }
} catch {
    throw ("wiso: " + $_.Exception.Message)
}
