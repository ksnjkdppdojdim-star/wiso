#Requires -Version 5.1
# Branche nmap optionnel (binaire deja installe sur l'agent).

function Invoke-WisoNmap {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [string]$ExtraArgs = "-F"
    )
    $nmap = $null
    $candidates = @(
        "$env:ProgramFiles\nmap\nmap.exe",
        "${env:ProgramFiles(x86)}\nmap\nmap.exe",
        "nmap.exe"
    )
    foreach ($c in $candidates) {
        if ($c -eq "nmap.exe") {
            $cmd = Get-Command nmap.exe -ErrorAction SilentlyContinue
            if ($cmd) { $nmap = $cmd.Source; break }
            continue
        }
        if (Test-Path -LiteralPath $c) {
            $nmap = $c
            break
        }
    }
    if (-not $nmap) {
        throw "nmap.exe introuvable sur cet agent. Installez Nmap ou utilisez wiso scan / wiso portscan."
    }

    $args = "$ExtraArgs $Target".Trim()
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(("=== nmap via wiso: {0} {1} ===" -f $nmap, $args))
    $out = Invoke-WisoNativeCommand -FileName $nmap -Arguments $args -WaitMs 25000 -FixConsoleEncoding
    $lines.Add($out)
    $lines.Add("(nmap externe - respectez la politique de scan de votre organisation)")
    return ($lines -join "`n")
}
