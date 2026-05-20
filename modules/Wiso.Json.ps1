#Requires -Version 5.1
# Sortie JSON pour sous-commandes wiso.

function ConvertTo-WisoJsonOutput {
    param([Parameter(Mandatory = $true)]$Data)
    return ($Data | ConvertTo-Json -Depth 6 -Compress:$false)
}

function Invoke-WisoJsonCommand {
    param([string[]]$SubArgs)

    if ($SubArgs.Count -lt 1) {
        throw (New-WisoUsageError "wiso json <wifi|profiles|interfaces|neighbors|dns|gateway|lan|who|version|firewall|listeners>")
    }

    $sub = $SubArgs[0].Trim().ToLowerInvariant()
    $rest = @()
    if ($SubArgs.Count -gt 1) { $rest = $SubArgs[1..($SubArgs.Count - 1)] }

    $obj = $null
    switch -Regex ($sub) {
        "^(wifi|wlan)$" {
            $obj = Get-WisoWifiStatusObject
        }
        "^(profiles|list)$" {
            $obj = @{
                command     = "profiles"
                computer    = $env:COMPUTERNAME
                profileCount = (Get-WisoWlanProfileNames).Count
                profiles    = @(Get-WisoWlanProfileNames)
            }
        }
        "^(interfaces|if)$" {
            $obj = @{
                command    = "interfaces"
                computer   = $env:COMPUTERNAME
                interfaces = @(Get-WisoInterfacesObject)
            }
        }
        "^neighbors$" {
            $obj = @{
                command   = "neighbors"
                computer  = $env:COMPUTERNAME
                neighbors = @(Get-WisoNeighborsBriefObject)
            }
        }
        "^dns$" {
            $obj = @{
                command = "dns"
                computer = $env:COMPUTERNAME
                resolvers = @(Get-WisoDnsObject)
            }
        }
        "^(gateway|gw)$" {
            $obj = Get-WisoGatewayObject
        }
        "^lan$" {
            $max = 24
            $parallel = $false
            $i = 0
            while ($i -lt $rest.Count) {
                $tok = $rest[$i].Trim().ToLowerInvariant()
                if ($tok -eq "parallel") { $parallel = $true; $i++; continue }
                if ($tok -eq "max" -and ($i + 1) -lt $rest.Count) {
                    [int]$max = $rest[$i + 1]
                    $i += 2
                    continue
                }
                if ($tok -match '^\d+$') { [int]$max = $tok; $i++; continue }
                $i++
            }
            $obj = Get-WisoLanObject -MaxHosts $max -Parallel:$parallel
        }
        "^who$" {
            $obj = @{
                command      = "who"
                computerName = $env:COMPUTERNAME
                userName     = $env:USERNAME
            }
        }
        "^(version|ver)$" {
            $obj = @{
                command    = "version"
                wiso       = (Get-WisoVersion)
                computer   = $env:COMPUTERNAME
                powershell = "$($PSVersionTable.PSVersion)"
                root       = (Get-WisoInstallRoot)
            }
        }
        "^(firewall|fw)$" {
            $obj = @{
                command  = "firewall"
                computer = $env:COMPUTERNAME
                profiles = @(Get-WisoFirewallObject)
            }
        }
        "^(listeners|listen)$" {
            $obj = @{
                command   = "listeners"
                computer  = $env:COMPUTERNAME
                listeners = @(Get-WisoListenersObject)
            }
        }
        default {
            throw (New-WisoUsageError "json sous-commande '$sub' non supportee")
        }
    }

    return (ConvertTo-WisoJsonOutput -Data $obj)
}

function Get-WisoInterfacesObject {
    Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4Address } |
        ForEach-Object {
            @{
                alias   = $_.InterfaceAlias
                ipv4    = @($_.IPv4Address.IPAddress)
                gateway = if ($_.IPv4DefaultGateway) { $_.IPv4DefaultGateway.NextHop } else { $null }
            }
        }
}

function Get-WisoDnsObject {
    Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.ServerAddresses -and $_.ServerAddresses.Count -gt 0 } |
        ForEach-Object {
            @{
                alias   = $_.InterfaceAlias
                servers = @($_.ServerAddresses)
            }
        }
}

function Get-WisoGatewayObject {
    $routes = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric |
        Select-Object -First 3
    @{
        command = "gateway"
        computer = $env:COMPUTERNAME
        routes = @(
            $routes | ForEach-Object {
                $ifAlias = $null
                if ($_.InterfaceIndex) {
                    $iface = Get-NetIPInterface -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
                    if ($iface) { $ifAlias = $iface.InterfaceAlias }
                }
                @{
                    nextHop = $_.NextHop
                    metric  = $_.RouteMetric
                    iface   = $ifAlias
                }
            }
        )
    }
}

function Get-WisoFirewallObject {
    Get-NetFirewallProfile -ErrorAction SilentlyContinue | ForEach-Object {
        @{
            name    = $_.Name
            enabled = [bool]$_.Enabled
        }
    }
}

function Get-WisoListenersObject {
    Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Group-Object LocalPort |
        Sort-Object Count -Descending |
        Select-Object -First 40 |
        ForEach-Object {
            $g = $_.Group[0]
            @{
                port  = [int]$g.LocalPort
                bind  = $g.LocalAddress
                count = $_.Count
            }
        }
}

function Get-WisoNeighborsBriefObject {
    $raw = Invoke-WisoNeighborsArp
    $parsed = Invoke-WisoParseArpTable -ArpText $raw
    $parsed | Where-Object { Test-WisoIsUsefulArpHost -Ip $_.IP -Mac $_.MAC } | ForEach-Object {
        @{
            interface = $_.Interface
            ip        = $_.IP
            mac       = $_.MAC
            type      = $_.Type
        }
    }
}

function Get-WisoLanObject {
    param(
        [int]$MaxHosts = 24,
        [switch]$Parallel
    )
    if ($Parallel) {
        $text = Invoke-WisoLanParallel -MaxHosts $MaxHosts
    } else {
        $text = Invoke-WisoLan -MaxHosts $MaxHosts
    }
    $alive = @()
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^\s*ALIVE\s+(\d{1,3}(?:\.\d{1,3}){3})') {
            $alive += $Matches[1]
        }
    }
    $ctx = $null
    try { $ctx = Get-WisoLanSubnetContext } catch { }
    @{
        command  = "lan"
        computer = $env:COMPUTERNAME
        subnet   = if ($ctx) { "{0}.0/24" -f $ctx.Base } else { $null }
        gateway  = if ($ctx) { $ctx.Gateway } else { $null }
        parallel = [bool]$Parallel
        maxHosts = $MaxHosts
        alive    = $alive
        aliveCount = $alive.Count
    }
}
