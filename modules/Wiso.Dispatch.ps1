#Requires -Version 5.1
# Routage des sous-commandes wiso (point d'orchestration).

function Invoke-WisoDispatch {
    param(
        [string[]]$PluginArgs = @()
    )

    $argsList = @()
    if ($null -ne $PluginArgs) { $argsList = @($PluginArgs) }

    if ($argsList.Count -eq 0) {
        return (Get-WisoHelpText)
    }

    $cmd = $argsList[0].Trim()
    $rest = @()
    if ($argsList.Count -gt 1) { $rest = $argsList[1..($argsList.Count - 1)] }

    switch -Regex ($cmd.ToLowerInvariant()) {
        "^(help|-h|--help)$" {
            return (Get-WisoHelpText)
        }
        "^(version|ver)$" {
            return (Invoke-WisoWithErrorContext -Branch "machine/version" -Action { Invoke-WisoVersionInfo })
        }
        "^(profiles|list)$" {
            return (Invoke-WisoWithErrorContext -Branch "wifi/profiles" -Action { Invoke-WisoWlanShowProfiles })
        }
        "^(wifi|wlan|radio)$" {
            if ($rest.Count -ge 1 -and $rest[0].Trim().ToLowerInvariant() -eq "raw") {
                return (Invoke-WisoWithErrorContext -Branch "wifi/raw" -Action { Invoke-WisoWlanCurrent })
            }
            return (Invoke-WisoWithErrorContext -Branch "wifi/summary" -Action { Invoke-WisoWlanCurrentSummary })
        }
        "^json$" {
            if ($rest.Count -lt 1) { throw (New-WisoUsageError "wiso json <wifi|profiles|interfaces|...>") }
            return (Invoke-WisoWithErrorContext -Branch "json" -Action { Invoke-WisoJsonCommand -SubArgs $rest })
        }
        "^show$" {
            if ($rest.Count -lt 1) { throw (New-WisoUsageError "wiso show <profil>") }
            $name = ($rest -join " ").Trim()
            return (Invoke-WisoWithErrorContext -Branch "wifi/show" -Action { Invoke-WisoWlanShowProfile -ProfileName $name })
        }
        "^(key|pw|password)$" {
            if ($rest.Count -lt 1) { throw (New-WisoUsageError "wiso key <profil>") }
            $name = ($rest -join " ").Trim()
            $sensitive = Invoke-WisoWithErrorContext -Branch "wifi/key" -Action { Invoke-WisoWlanShowProfile -ProfileName $name -WithKey }
            return @(
                "=== ATTENTION : sortie sensible (cle Wi-Fi en clair) ===",
                $sensitive
            ) -join "`n"
        }
        "^export$" {
            $withKeys = $false
            $max = 8
            $i = 0
            while ($i -lt $rest.Count) {
                $tok = $rest[$i].Trim().ToLowerInvariant()
                if ($tok -in @("keys", "key", "password", "pw")) {
                    $withKeys = $true
                    $i++
                    continue
                }
                if ($tok -eq "max" -and ($i + 1) -lt $rest.Count) {
                    [int]$max = $rest[$i + 1]
                    $i += 2
                    continue
                }
                $i++
            }
            return (Invoke-WisoWithErrorContext -Branch "wifi/export" -Action {
                Invoke-WisoWlanExport -WithKeys:$withKeys -MaxProfiles $max
            })
        }
        "^delete$" {
            if ($rest.Count -lt 1) { throw (New-WisoUsageError "wiso delete <profil> -force") }
            $force = $false
            $nameParts = New-Object System.Collections.Generic.List[string]
            foreach ($a in $rest) {
                if ($a.Trim().ToLowerInvariant() -in @("-force", "--force", "/force")) {
                    $force = $true
                } else {
                    $nameParts.Add($a) | Out-Null
                }
            }
            $name = ($nameParts -join " ").Trim()
            if ($name -eq "") { throw (New-WisoUsageError "wiso delete <profil> -force") }
            return (Invoke-WisoWithErrorContext -Branch "wifi/delete" -Action {
                Invoke-WisoWlanDeleteProfile -ProfileName $name -Force:$force
            })
        }
        "^nmap$" {
            if ($rest.Count -lt 1) { throw (New-WisoUsageError "wiso nmap <cible> [args]") }
            $target = $rest[0]
            $extra = "-F"
            if ($rest.Count -gt 1) {
                $extra = ($rest[1..($rest.Count - 1)] -join " ")
            }
            return (Invoke-WisoWithErrorContext -Branch "net/nmap" -Action { Invoke-WisoNmap -Target $target -ExtraArgs $extra })
        }
        "^(interfaces|if)$" {
            return (Invoke-WisoWithErrorContext -Branch "net/interfaces" -Action {
                ((Invoke-WisoInterfaces) -join "`n")
            })
        }
        "^(neighbors|arp)$" {
            if ($rest.Count -ge 1) {
                $mode = $rest[0].Trim().ToLowerInvariant()
                switch ($mode) {
                    "win" {
                        return (Invoke-WisoWithErrorContext -Branch "net/neighbors-win" -Action { Invoke-WisoNeighborsWin })
                    }
                    "brief" {
                        return (Invoke-WisoWithErrorContext -Branch "net/neighbors-brief" -Action { Invoke-WisoNeighborsBrief })
                    }
                    default {
                        throw (New-WisoUsageError "wiso neighbors [brief|win]")
                    }
                }
            }
            return (Invoke-WisoWithErrorContext -Branch "net/neighbors-arp" -Action { Invoke-WisoNeighborsArp })
        }
        "^brief$" {
            return (Invoke-WisoWithErrorContext -Branch "net/neighbors-brief" -Action { Invoke-WisoNeighborsBrief })
        }
        "^route$" {
            return (Invoke-WisoWithErrorContext -Branch "net/route" -Action { Invoke-WisoRoute })
        }
        "^dns$" {
            return (Invoke-WisoWithErrorContext -Branch "net/dns" -Action { Invoke-WisoDns })
        }
        "^(gateway|gw)$" {
            return (Invoke-WisoWithErrorContext -Branch "net/gateway" -Action { Invoke-WisoGateway })
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
            if ($parallel) {
                return (Invoke-WisoWithErrorContext -Branch "net/lan-parallel" -Action { Invoke-WisoLanParallel -MaxHosts $max })
            }
            return (Invoke-WisoWithErrorContext -Branch "net/lan" -Action { Invoke-WisoLan -MaxHosts $max })
        }
        "^ping$" {
            if ($rest.Count -lt 1) { throw (New-WisoUsageError "wiso ping <hote> [nombre]") }
            $target = $rest[0]
            $n = 2
            if ($rest.Count -ge 2) { [int]$n = $rest[1] }
            return (Invoke-WisoWithErrorContext -Branch "net/ping" -Action { Invoke-WisoPingExe -Target $target -Count $n })
        }
        "^port$" {
            if ($rest.Count -lt 2) { throw (New-WisoUsageError "wiso port <hote> <port>") }
            $h = $rest[0]
            $port = [int]$rest[1]
            return (Invoke-WisoWithErrorContext -Branch "net/port" -Action { Invoke-WisoPortTest -HostName $h -Port $port })
        }
        "^portscan$" {
            if ($rest.Count -lt 2) { throw (New-WisoUsageError "wiso portscan <hote> <ports>") }
            $h = $rest[0]
            $portsSpec = ($rest[1..($rest.Count - 1)] -join ",")
            return (Invoke-WisoWithErrorContext -Branch "net/portscan" -Action { Invoke-WisoPortscan -HostName $h -PortsSpec $portsSpec })
        }
        "^scan$" {
            if ($rest.Count -lt 1) { throw (New-WisoUsageError "wiso scan <hote> [quick]") }
            $h = $rest[0]
            if ($rest.Count -ge 2 -and $rest[1].Trim().ToLowerInvariant() -eq "quick") {
                return (Invoke-WisoWithErrorContext -Branch "net/scan-quick" -Action { Invoke-WisoTcpScanQuick -HostName $h })
            }
            if ($rest.Count -ge 1 -and $h.Trim().ToLowerInvariant() -eq "quick" -and $rest.Count -ge 2) {
                return (Invoke-WisoWithErrorContext -Branch "net/scan-quick" -Action { Invoke-WisoTcpScanQuick -HostName $rest[1] })
            }
            return (Invoke-WisoWithErrorContext -Branch "net/scan" -Action { Invoke-WisoTcpScan -HostName $h })
        }
        "^quick$" {
            if ($rest.Count -lt 2 -or $rest[0].Trim().ToLowerInvariant() -ne "scan") {
                throw (New-WisoUsageError "wiso quick scan <hote>")
            }
            $h = $rest[1]
            return (Invoke-WisoWithErrorContext -Branch "net/scan-quick" -Action { Invoke-WisoTcpScanQuick -HostName $h })
        }
        "^(firewall|fw)$" {
            return (Invoke-WisoWithErrorContext -Branch "sec/firewall" -Action { Invoke-WisoFirewall })
        }
        "^(listeners|listen)$" {
            return (Invoke-WisoWithErrorContext -Branch "sec/listeners" -Action { Invoke-WisoListeners })
        }
        "^(shares|share)$" {
            return (Invoke-WisoWithErrorContext -Branch "sec/shares" -Action { Invoke-WisoShares })
        }
        "^who$" {
            return (Invoke-WisoWithErrorContext -Branch "machine/who" -Action { Invoke-WisoWho })
        }
        default {
            if ($argsList.Count -eq 1 -and -not (Test-WisoReservedWord $cmd)) {
                $name = $argsList[0].Trim()
                $body = Invoke-WisoWithErrorContext -Branch "wifi/key-shortcut" -Action { Invoke-WisoWlanShowProfile -ProfileName $name -WithKey }
                return @(
                    "=== Raccourci wiso '$name' => profil + cle (key=clear) ===",
                    $body
                ) -join "`n"
            }
            throw (New-WisoUsageError "sous-commande inconnue '$cmd'. Tapez: wiso help")
        }
    }
}
