#Requires -Version 5.1
# Fonctions communes : mots réservés, erreurs typées, racine d'installation.

function Get-WisoReservedWords {
    return @(
        "help", "-h", "--help", "profiles", "list", "wifi", "show", "key", "pw", "password",
        "interfaces", "if", "neighbors", "arp", "ping", "port", "scan", "who"
    )
}

function Test-WisoReservedWord {
    param([string]$Word)
    if ($null -eq $Word) { return $false }
    $w = $Word.Trim().ToLowerInvariant()
    return (Get-WisoReservedWords) -contains $w
}

function New-WisoUsageError {
    param([string]$Message)
    return [System.Management.Automation.RuntimeException]::new("wiso usage: $Message")
}

function Invoke-WisoWithErrorContext {
    param(
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )
    try {
        & $Action
    } catch {
        $inner = $_.Exception.Message
        throw [System.Management.Automation.RuntimeException]::new(
            "wiso [$Branch] $inner",
            $_.Exception
        )
    }
}
