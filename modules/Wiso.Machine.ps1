#Requires -Version 5.1
# Branche machine : identite locale.

function Invoke-WisoWho {
    $lines = @(
        ("ComputerName: {0}" -f $env:COMPUTERNAME),
        ("UserName:     {0}" -f $env:USERNAME)
    )
    return $lines -join "`n"
}
