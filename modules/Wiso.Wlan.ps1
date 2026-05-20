#Requires -Version 5.1
# Branche Wi-Fi : netsh wlan.

function Invoke-WisoWlanShowProfiles {
    & netsh.exe wlan show profiles 2>&1 | ForEach-Object { "$_" }
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
        & netsh.exe wlan show profile $nameArg key=clear 2>&1 | ForEach-Object { "$_" }
    } else {
        & netsh.exe wlan show profile $nameArg 2>&1 | ForEach-Object { "$_" }
    }
}
