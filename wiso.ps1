#Requires -Version 5.1
<#
.SYNOPSIS
  wiso — plugin Trish : Wi‑Fi (netsh), réseau local léger, tests de connectivité.

  Exemples côté CLI Trish :
    trish exec <agent> wiso profiles
    trish exec <agent> wiso "Mon WiFi"
#>

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PluginArgs
)

$ErrorActionPreference = "Stop"

function Get-WisoHelp {
    @'
wiso - audit reseau / Wi-Fi (usage interne, machines autorisees uniquement)

Wi-Fi
  wiso profiles              Liste des profils WLAN
  wiso show <profil>         Detail du profil sans cle en clair
  wiso key <profil>          Profil + cle en clair (key=clear) - sensible
  wiso "<profil>"            Raccourci : comme "wiso key <profil>" (un seul argument)

Reseau (leger, complement rapide - pas un equivalent nmap)
  wiso interfaces            Adresses IPv4 par interface
  wiso neighbors             Voisins IPv4 (Get-NetNeighbor)
  wiso ping <hote> [n]       Ping ICMP (defaut n=2)
  wiso port <hote> <port>    Test-NetConnection TCP
  wiso scan <hote>           Ports TCP courants (22,80,135,139,443,445,3389,5985)

Machine
  wiso who                   Hostname + utilisateur

Aide
  wiso help
'@
}

function Invoke-WlanShowProfiles {
    & netsh.exe wlan show profiles 2>&1 | ForEach-Object { "$_" }
}

function Invoke-WlanShowProfile {
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

function Test-ReservedWord {
    param([string]$Word)
    if ($null -eq $Word) { return $false }
    $w = $Word.Trim().ToLowerInvariant()
    @(
        "help", "-h", "--help", "profiles", "list", "wifi", "show", "key", "pw", "password",
        "interfaces", "if", "neighbors", "arp", "ping", "port", "scan", "who"
    ) -contains $w
}

$argsList = @()
if ($null -ne $PluginArgs) { $argsList = @($PluginArgs) }

if ($argsList.Count -eq 0) {
    Write-Output (Get-WisoHelp)
    exit 0
}

$cmd = $argsList[0].Trim()
$rest = @()
if ($argsList.Count -gt 1) { $rest = $argsList[1..($argsList.Count - 1)] }

switch -Regex ($cmd.ToLowerInvariant()) {
    "^(help|-h|--help)$" {
        Write-Output (Get-WisoHelp)
    }
    "^(profiles|list|wifi)$" {
        Write-Output (Invoke-WlanShowProfiles)
    }
    "^show$" {
        if ($rest.Count -lt 1) { throw "usage: wiso show <profil>" }
        $name = ($rest -join " ").Trim()
        Write-Output (Invoke-WlanShowProfile -ProfileName $name)
    }
    "^(key|pw|password)$" {
        if ($rest.Count -lt 1) { throw "usage: wiso key <profil>" }
        $name = ($rest -join " ").Trim()
        Write-Output "=== ATTENTION : sortie sensible (cle Wi-Fi en clair) ==="
        Write-Output (Invoke-WlanShowProfile -ProfileName $name -WithKey)
    }
    "^(interfaces|if)$" {
        Get-NetIPConfiguration |
            Where-Object { $_.IPv4Address } |
            ForEach-Object {
                $ip = ($_.IPv4Address.IPAddress -join ", ")
                "{0,-32} IPv4: {1}" -f $_.InterfaceAlias, $ip
            } | Write-Output
    }
    "^(neighbors|arp)$" {
        Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.State -match "Reachable|Stale|Permanent" } |
            Sort-Object InterfaceAlias, IPAddress |
            Format-Table -AutoSize InterfaceAlias, IPAddress, LinkLayerAddress, State |
            Out-String -Width 4096 | Write-Output
    }
    "^ping$" {
        if ($rest.Count -lt 1) { throw "usage: wiso ping <hôte> [nombre]" }
        $target = $rest[0]
        $n = 2
        if ($rest.Count -ge 2) { [int]$n = $rest[1] }
        Test-Connection -ComputerName $target -Count $n -ErrorAction Stop |
            Format-Table -AutoSize |
            Out-String -Width 4096 | Write-Output
    }
    "^port$" {
        if ($rest.Count -lt 2) { throw "usage: wiso port <hôte> <port>" }
        $h = $rest[0]
        $port = [int]$rest[1]
        $r = Test-NetConnection -ComputerName $h -Port $port -WarningAction SilentlyContinue
        "ComputerName={0} RemotePort={1} TcpTestSucceeded={2} PingSucceeded={3}" -f `
            $r.ComputerName, $r.RemotePort, $r.TcpTestSucceeded, $r.PingSucceeded | Write-Output
    }
    "^scan$" {
        if ($rest.Count -lt 1) { throw "usage: wiso scan <hôte>" }
        $h = $rest[0]
        $ports = @(22, 80, 135, 139, 443, 445, 3389, 5985)
        foreach ($p in $ports) {
            $r = Test-NetConnection -ComputerName $h -Port $p -WarningAction SilentlyContinue
            if ($r.TcpTestSucceeded) {
                "OPEN  tcp/{0}" -f $p | Write-Output
            } else {
                "closed tcp/{0}" -f $p | Write-Output
            }
        }
    }
    "^who$" {
        "ComputerName: {0}" -f $env:COMPUTERNAME | Write-Output
        "UserName:     {0}" -f $env:USERNAME | Write-Output
    }
    default {
        if ($argsList.Count -eq 1 -and -not (Test-ReservedWord $cmd)) {
            $name = $argsList[0].Trim()
            Write-Output "=== Raccourci wiso '$name' => profil + cle (key=clear) ==="
            Write-Output (Invoke-WlanShowProfile -ProfileName $name -WithKey)
        } else {
            throw "Sous-commande inconnue: '$cmd'. Tapez: wiso help"
        }
    }
}
