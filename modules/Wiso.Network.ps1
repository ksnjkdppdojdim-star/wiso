#Requires -Version 5.1
# Branche reseau : interfaces, voisins, ping, port, scan — optimise pour reponses rapides.

function Test-WisoTcpConnect {
    param(
        [Parameter(Mandatory = $true)][string]$ComputerName,
        [Parameter(Mandatory = $true)][int]$Port,
        [int]$TimeoutMs = 900
    )
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            return $false
        }
        $client.EndConnect($iar)
        return $true
    } catch {
        return $false
    } finally {
        if ($null -ne $client) {
            try { $client.Close() } catch { }
        }
    }
}

function Invoke-WisoInterfaces {
    return @(
        Get-NetIPConfiguration |
            Where-Object { $_.IPv4Address } |
            ForEach-Object {
                $ip = ($_.IPv4Address.IPAddress -join ", ")
                "{0,-32} IPv4: {1}" -f $_.InterfaceAlias, $ip
            }
    )
}

function Invoke-WisoNeighborsArp {
    # arp -a est en general beaucoup plus rapide que Get-NetNeighbor (important pour le timeout Trish CLI).
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "$env:ComSpec"
    $psi.Arguments = "/c arp -a"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $null = $p.WaitForExit(8000)
    if (-not [string]::IsNullOrWhiteSpace($err)) {
        $out + "`n" + $err
    } else {
        $out
    }
}

function Invoke-WisoNeighborsWin {
    param([int]$MaxRows = 400)
    Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.State -match "Reachable|Stale|Permanent" } |
        Sort-Object InterfaceAlias, IPAddress |
        Select-Object -First $MaxRows |
        Format-Table -AutoSize InterfaceAlias, IPAddress, LinkLayerAddress, State |
        Out-String -Width 4096
}

function Invoke-WisoPingExe {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [int]$Count = 2
    )
    if ($Count -lt 1) { $Count = 1 }
    if ($Count -gt 20) { $Count = 20 }
    $w = 1200
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "$env:SystemRoot\System32\ping.exe"
    $psi.Arguments = "-n $Count -w $w `"$Target`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $null = $p.WaitForExit(15000)
    $out
}

function Invoke-WisoPortTest {
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][int]$Port
    )
    $ok = Test-WisoTcpConnect -ComputerName $HostName -Port $Port -TimeoutMs 1200
    "Target={0} Port={1} TcpOpen={2}" -f $HostName, $Port, $ok
}

function Invoke-WisoTcpScan {
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [int[]]$Ports = @(22, 80, 135, 139, 443, 445, 3389, 5985),
        [int]$TimeoutMsPerPort = 700
    )
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($p in $Ports) {
        $open = Test-WisoTcpConnect -ComputerName $HostName -Port $p -TimeoutMs $TimeoutMsPerPort
        if ($open) {
            $lines.Add(("OPEN  tcp/{0}" -f $p))
        } else {
            $lines.Add(("closed tcp/{0}" -f $p))
        }
    }
    $lines.Add("(scan TCP court par port - pas un equivalent nmap)")
    return $lines -join "`n"
}
