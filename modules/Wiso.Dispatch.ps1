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
        "^(profiles|list|wifi)$" {
            return (Invoke-WisoWithErrorContext -Branch "wifi/profiles" -Action { Invoke-WisoWlanShowProfiles })
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
        "^(interfaces|if)$" {
            return (Invoke-WisoWithErrorContext -Branch "net/interfaces" -Action {
                ((Invoke-WisoInterfaces) -join "`n")
            })
        }
        "^(neighbors|arp)$" {
            if ($rest.Count -ge 1 -and $rest[0].Trim().ToLowerInvariant() -eq "win") {
                return (Invoke-WisoWithErrorContext -Branch "net/neighbors-win" -Action { Invoke-WisoNeighborsWin })
            }
            return (Invoke-WisoWithErrorContext -Branch "net/neighbors-arp" -Action { Invoke-WisoNeighborsArp })
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
        "^scan$" {
            if ($rest.Count -lt 1) { throw (New-WisoUsageError "wiso scan <hote>") }
            $h = $rest[0]
            return (Invoke-WisoWithErrorContext -Branch "net/scan" -Action { Invoke-WisoTcpScan -HostName $h })
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
