#Requires -Version 5.1
# Branche securite locale : pare-feu, ecoutes, partages.

function Invoke-WisoFirewall {
    $lines = New-Object System.Collections.Generic.List[string]
    Get-NetFirewallProfile -ErrorAction SilentlyContinue | ForEach-Object {
        $state = if ($_.Enabled) { "enabled" } else { "disabled" }
        $lines.Add(("{0,-12} {1}" -f $_.Name, $state))
    }
    if ($lines.Count -eq 0) {
        return "Aucun profil pare-feu (Get-NetFirewallProfile indisponible)."
    }
    return ($lines -join "`n")
}

function Invoke-WisoListeners {
    param([int]$MaxRows = 80)
    $rows = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalAddress -notmatch "^::$" } |
        Group-Object LocalPort, LocalAddress |
        Sort-Object Count -Descending |
        Select-Object -First $MaxRows

    if (-not $rows) {
        return "Aucune socket TCP en ecoute detectee."
    }

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($g in $rows) {
        $first = $g.Group[0]
        $lines.Add(("{0,-6} {1,-24} ({2} bindings)" -f $first.LocalPort, $first.LocalAddress, $g.Count))
    }
    return ($lines -join "`n")
}

function Invoke-WisoShares {
    Invoke-WisoNativeCommand -FileName "$env:ComSpec" -Arguments '/c net share' -FixConsoleEncoding
}
