#Requires -Version 5.1
# Branche machine : identite locale, version plugin.

function Invoke-WisoWho {
    $lines = @(
        ("ComputerName: {0}" -f $env:COMPUTERNAME),
        ("UserName:     {0}" -f $env:USERNAME)
    )
    return $lines -join "`n"
}

function Invoke-WisoVersionInfo {
    return @(
        ("wiso version: {0}" -f (Get-WisoVersion)),
        ("plugin root:  {0}" -f (Get-WisoInstallRoot)),
        ("PowerShell:   {0}" -f $PSVersionTable.PSVersion)
    ) -join "`n"
}
