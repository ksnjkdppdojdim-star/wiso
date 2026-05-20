#Requires -Version 5.1
# Branche Wi-Fi : netsh wlan.

function Invoke-WisoWlanShowProfiles {
    Invoke-WisoNativeCommand -FileName "netsh.exe" -Arguments "wlan show profiles" -FixConsoleEncoding
}

function Get-WisoWlanProfileNames {
    $text = Invoke-WisoWlanShowProfiles
    $names = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^\s{2,}[^:]+:\s+(.+?)\s*$') {
            if ($line -match 'interface|Interface|carte|Card|Wi-?Fi|radio|Profils sur|Profiles on|policy|Policy') {
                continue
            }
            $n = $Matches[1].Trim()
            if ($n -eq "" -or $seen.ContainsKey($n)) { continue }
            $seen[$n] = $true
            $names.Add($n) | Out-Null
        }
    }
    return @($names)
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

function Invoke-WisoWlanExport {
    param(
        [switch]$WithKeys,
        [int]$MaxProfiles = 8
    )
    if ($MaxProfiles -lt 1) { $MaxProfiles = 1 }
    if ($MaxProfiles -gt 20) { $MaxProfiles = 20 }

    $names = Get-WisoWlanProfileNames
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("=== wiso export $(Get-WisoVersion) sur $env:COMPUTERNAME ===")
    $lines.Add(("Profils trouves: {0}" -f $names.Count))
    if ($WithKeys) {
        $lines.Add("Mode: AVEC cles (key=clear) - DONNEES SENSIBLES")
    } else {
        $lines.Add("Mode: sans cles (ajoutez 'keys' pour inclure les mots de passe)")
    }
    $lines.Add("")
    $lines.Add("--- Connexion active ---")
    $lines.Add((Invoke-WisoWlanCurrent))
    $lines.Add("")

    $total = $names.Count
    $limit = [Math]::Min($total, $MaxProfiles)
    if ($total -gt $MaxProfiles) {
        $lines.Add(("ATTENTION: export limite a {0}/{1} profils (timeout Trish). Relancez par profil si besoin." -f $MaxProfiles, $total))
        $lines.Add("")
    }

    for ($i = 0; $i -lt $limit; $i++) {
        $name = $names[$i]
        $lines.Add(("========== [{0}/{1}] {2} ==========" -f ($i + 1), $limit, $name))
        if ($WithKeys) {
            $lines.Add((Invoke-WisoWlanShowProfile -ProfileName $name -WithKey))
        } else {
            $lines.Add((Invoke-WisoWlanShowProfile -ProfileName $name))
        }
        $lines.Add("")
    }

    if ($total -eq 0) {
        $lines.Add("Aucun profil WLAN enregistre detecte.")
    }

    return ($lines -join "`n")
}

function Invoke-WisoWlanDeleteProfile {
    param(
        [Parameter(Mandatory = $true)][string]$ProfileName,
        [switch]$Force
    )
    if ([string]::IsNullOrWhiteSpace($ProfileName)) {
        throw "Nom de profil vide."
    }
    if (-not $Force) {
        return @(
            "Refuse: suppression non confirmee.",
            ("Profil cible: {0}" -f $ProfileName),
            "Pour supprimer: wiso delete `"$ProfileName`" -force"
        ) -join "`n"
    }

    $safe = $ProfileName.Replace('"', "'")
    $nameArg = 'name="' + $safe + '"'
    $out = Invoke-WisoNativeCommand -FileName "netsh.exe" -Arguments "wlan delete profile $nameArg" -FixConsoleEncoding
    if ([string]::IsNullOrWhiteSpace($out)) {
        return ("Profil supprime (ou commande executee): {0}" -f $ProfileName)
    }
    return $out
}
