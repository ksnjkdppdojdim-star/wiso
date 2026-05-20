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

function Parse-WisoWlanInterfaceBlock {
    param([string]$BlockText)
    $fields = @{}
    foreach ($line in ($BlockText -split "`r?`n")) {
        if ($line -match '^\s+(.+?)\s*:\s*(.+)\s*$') {
            $key = $Matches[1].Trim().ToLowerInvariant()
            $key = $key -replace 'é','e' -replace 'è','e' -replace 'ê','e' -replace 'à','a' -replace 'û','u' -replace 'ô','o'
            $key = $key -replace '[^a-z0-9]', ''
            $fields[$key] = $Matches[2].Trim()
        }
    }
    return $fields
}

function Get-WisoWifiStatusObject {
    $raw = Invoke-WisoWlanCurrent
    $blocks = @()
    $current = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($raw -split "`r?`n")) {
        if ($line -match '^\s*$' -and $current.Count -gt 0) {
            $blocks += (($current -join "`n"))
            $current.Clear()
            continue
        }
        if ($line -match '^\S') {
            if ($current.Count -gt 0) {
                $blocks += (($current -join "`n"))
                $current.Clear()
            }
        }
        $current.Add($line) | Out-Null
    }
    if ($current.Count -gt 0) {
        $blocks += (($current -join "`n"))
    }

    $ifaces = @()
    foreach ($b in $blocks) {
        if ($b -notmatch ':') { continue }
        $f = Parse-WisoWlanInterfaceBlock -BlockText $b
        if ($f.Count -eq 0) { continue }
        $ifaces += @{
            name           = $(if ($f['name']) { $f['name'] } else { $f['nom'] })
            description    = $f['description']
            guid           = $f['guid']
            state          = $(if ($f['state']) { $f['state'] } else { $f['etat'] })
            ssid           = $f['ssid']
            bssid          = $f['bssid']
            networkType    = $(if ($f['networktype']) { $f['networktype'] } else { $f['typereseau'] })
            radioType      = $(if ($f['radiotype']) { $f['radiotype'] } else { $f['typeradio'] })
            authentication = $(if ($f['authentication']) { $f['authentication'] } else { $f['authentification'] })
            cipher         = $(if ($f['cipher']) { $f['cipher'] } else { $f['chiffrement'] })
            channel        = $(if ($f['channel']) { $f['channel'] } else { $f['canal'] })
            signal         = $f['signal']
            receiveRate    = $(if ($f['receivrate']) { $f['receivrate'] } else { $f['rceptionmbps'] })
            transmitRate   = $(if ($f['transmitrate']) { $f['transmitrate'] } else { $f['transmissionmbps'] })
        }
    }

    return @{
        command    = "wifi"
        computer   = $env:COMPUTERNAME
        interfaces = $ifaces
    }
}

function Invoke-WisoWlanCurrentSummary {
    $obj = Get-WisoWifiStatusObject
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("=== Wi-Fi actif sur $env:COMPUTERNAME ===")
    if ($obj.interfaces.Count -eq 0) {
        $lines.Add("Aucune interface WLAN detectee ou non connectee.")
        return ($lines -join "`n")
    }
    foreach ($ifc in $obj.interfaces) {
        $lines.Add("")
        $lines.Add(("Interface: {0}" -f $(if ($ifc.name) { $ifc.name } else { "?" })))
        $lines.Add(("  Etat:     {0}" -f $(if ($ifc.state) { $ifc.state } else { "-" })))
        $lines.Add(("  SSID:     {0}" -f $(if ($ifc.ssid) { $ifc.ssid } else { "-" })))
        $lines.Add(("  Signal:   {0}" -f $(if ($ifc.signal) { $ifc.signal } else { "-" })))
        $lines.Add(("  Canal:    {0}" -f $(if ($ifc.channel) { $ifc.channel } else { "-" })))
        $lines.Add(("  Auth:     {0}" -f $(if ($ifc.authentication) { $ifc.authentication } else { "-" })))
        $lines.Add(("  Radio:    {0}" -f $(if ($ifc.radioType) { $ifc.radioType } else { "-" })))
    }
    $lines.Add("")
    $lines.Add("(wiso wifi raw = sortie netsh complete)")
    return ($lines -join "`n")
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
