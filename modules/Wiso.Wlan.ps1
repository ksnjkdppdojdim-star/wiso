#Requires -Version 5.1
# Branche Wi-Fi : netsh wlan.

function Invoke-WisoWlanShowProfiles {
    Invoke-WisoNativeCommand -FileName "netsh.exe" -Arguments "wlan show profiles" -FixConsoleEncoding
}

function Invoke-WisoWlanShowProfile {
    param(
        [Parameter(Mandatory = $true)][string]$ProfileName,
        [switch]$WithKey
    )
    if ([string]::IsNullOrWhiteSpace($ProfileName)) {
        throw "Nom de profil vide."
    }
    $safe = $ProfileName.Replace('"', "'")
    $nameArg = 'name="' + $safe + '"'
    if ($WithKey) {
        $args = "wlan show profile $nameArg key=clear"
    } else {
        $args = "wlan show profile $nameArg"
    }
    Invoke-WisoNativeCommand -FileName "netsh.exe" -Arguments $args -FixConsoleEncoding
}

function Invoke-WisoWlanCurrent {
    Invoke-WisoNativeCommand -FileName "netsh.exe" -Arguments "wlan show interfaces" -FixConsoleEncoding
}
