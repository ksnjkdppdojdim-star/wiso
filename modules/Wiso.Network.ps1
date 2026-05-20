#Requires -Version 5.1
# Branche reseau : interfaces, voisins, ping, scan, route, dns, gateway, lan.

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
    Invoke-WisoNativeCommand -FileName "$env:ComSpec" -Arguments '/c arp -a' -FixConsoleEncoding
}

function Invoke-WisoParseArpTable {
    param([string]$ArpText)
    $entries = New-Object System.Collections.Generic.List[object]
    $currentInterface = ""
    foreach ($line in ($ArpText -split "`r?`n")) {
        if ($line -match 'Interface:\s*(\d{1,3}(?:\.\d{1,3}){3})') {
            $currentInterface = $Matches[1]
            continue
        }
        if ($line -match '^\s*(\d{1,3}(?:\.\d{1,3}){3})\s+([0-9a-fA-F-]+)\s+(\S+)') {
            $ip = $Matches[1]
            $mac = $Matches[2]
            $type = $Matches[3]
            $entries.Add([pscustomobject]@{
                Interface = $currentInterface
                IP        = $ip
                MAC       = $mac
                Type      = $type
            })
        }
    }
    return $entries
}

function Test-WisoIsUsefulArpHost {
    param([string]$Ip, [string]$Mac)
    if ($Ip -match '^224\.|^239\.|^255\.255\.255\.255$') { return $false }
    if ($Mac -match '^ff-ff-ff-ff-ff-ff$') { return $false }
    if ($Ip -match '^224\.0\.0\.') { return $false }
    return $true
}

function Invoke-WisoNeighborsBrief {
    $raw = Invoke-WisoNeighborsArp
    $parsed = Invoke-WisoParseArpTable -ArpText $raw
    $lines = New-Object System.Collections.Generic.List[string]
    $lastIface = ""
    foreach ($e in ($parsed | Where-Object { Test-WisoIsUsefulArpHost -Ip $_.IP -Mac $_.MAC })) {
        if ($e.Interface -ne $lastIface) {
            $lines.Add("")
            $lines.Add(("[{0}]" -f $e.Interface))
            $lastIface = $e.Interface
        }
        $lines.Add(("  {0,-18} {1,-20} {2}" -f $e.IP, $e.MAC, $e.Type))
    }
    if ($lines.Count -eq 0) {
        return "Aucun voisin utile (hors multicast/broadcast)."
    }
    return ($lines -join "`n").Trim()
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
    Invoke-WisoNativeCommand -FileName "$env:SystemRoot\System32\ping.exe" `
        -Arguments "-n $Count -w $w `"$Target`"" -WaitMs 15000 -FixConsoleEncoding
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

function Invoke-WisoTcpScanQuick {
    param([Parameter(Mandatory = $true)][string]$HostName)
    Invoke-WisoTcpScan -HostName $HostName -Ports @(80, 443, 445, 3389) -TimeoutMsPerPort 500
}

function Invoke-WisoPortscan {
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][string]$PortsSpec
    )
    $ports = @()
    foreach ($part in ($PortsSpec -split '[,\s;]+')) {
        $part = $part.Trim()
        if ($part -eq "") { continue }
        $n = 0
        if ([int]::TryParse($part, [ref]$n) -and $n -ge 1 -and $n -le 65535) {
            $ports += $n
        }
    }
    $ports = $ports | Select-Object -Unique
    if ($ports.Count -eq 0) {
        throw "Liste de ports vide (ex: 80,443,8080)."
    }
    if ($ports.Count -gt 12) {
        throw "Maximum 12 ports par invocation (limite timeout Trish)."
    }
    Invoke-WisoTcpScan -HostName $HostName -Ports $ports -TimeoutMsPerPort 600
}

function Invoke-WisoRoute {
    Invoke-WisoNativeCommand -FileName "$env:ComSpec" -Arguments '/c route print -4' -WaitMs 10000 -FixConsoleEncoding
}

function Invoke-WisoDns {
    $lines = New-Object System.Collections.Generic.List[string]
    Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.ServerAddresses -and $_.ServerAddresses.Count -gt 0 } |
        ForEach-Object {
            $srv = $_.ServerAddresses -join ", "
            $lines.Add(("{0,-32} DNS: {1}" -f $_.InterfaceAlias, $srv))
        }
    if ($lines.Count -eq 0) {
        return "Aucun serveur DNS IPv4 configure."
    }
    return ($lines -join "`n")
}

function Invoke-WisoGateway {
    $lines = New-Object System.Collections.Generic.List[string]
    $routes = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric |
        Select-Object -First 3
    foreach ($r in $routes) {
        $ifAlias = ""
        if ($r.InterfaceIndex) {
            $iface = Get-NetIPInterface -InterfaceIndex $r.InterfaceIndex -ErrorAction SilentlyContinue
            if ($iface) { $ifAlias = $iface.InterfaceAlias }
        }
        $lines.Add(("{0,-18} via {1,-15} metric={2} if={3}" -f "0.0.0.0/0", $r.NextHop, $r.RouteMetric, $ifAlias))
    }
    if ($lines.Count -eq 0) {
        return "Aucune route par defaut IPv4."
    }
    $gw = ($routes | Select-Object -First 1).NextHop
    if ($gw) {
        $lines.Add("")
        $lines.Add("--- ping passerelle ($gw) ---")
        $pingOut = Invoke-WisoPingExe -Target $gw -Count 1
        $lines.Add($pingOut)
    }
    return ($lines -join "`n")
}

function Test-WisoPingHostOnce {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [int]$WaitMs = 200
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "$env:SystemRoot\System32\ping.exe"
    $psi.Arguments = "-n 1 -w $WaitMs `"$Target`""
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $null = $p.StandardOutput.ReadToEnd()
    $null = $p.WaitForExit(2000)
    return ($p.ExitCode -eq 0)
}

function Get-WisoLanSubnetContext {
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address } |
        Select-Object -First 1
    if (-not $cfg) {
        throw "Aucune interface IPv4 avec passerelle."
    }
    $ip = $cfg.IPv4Address.IPAddress
    if ($ip -is [array]) { $ip = $ip[0] }
    $prefix = $cfg.IPv4Address.PrefixLength
    if ($prefix -ne 24) {
        throw ("Prefix /{0} non supporte pour lan (seul /24)." -f $prefix)
    }
    $octets = $ip -split '\.'
    if ($octets.Count -ne 4) {
        throw "Adresse IPv4 invalide: $ip"
    }
    return @{
        Base      = "{0}.{1}.{2}" -f $octets[0], $octets[1], $octets[2]
        Gateway   = $cfg.IPv4DefaultGateway.NextHop
        Interface = $cfg.InterfaceAlias
    }
}

function Invoke-WisoLanParallel {
    param(
        [int]$MaxHosts = 24,
        [int]$Throttle = 8
    )
    if ($MaxHosts -lt 1) { $MaxHosts = 1 }
    if ($MaxHosts -gt 32) { $MaxHosts = 32 }
    if ($Throttle -lt 2) { $Throttle = 2 }
    if ($Throttle -gt 16) { $Throttle = 16 }

    $ctx = Get-WisoLanSubnetContext
    $base = $ctx.Base
    $gw = $ctx.Gateway

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(("Subnet: {0}.0/24 (interface {1})" -f $base, $ctx.Interface))
    $lines.Add(("Gateway: {0}" -f $gw))
    $lines.Add(("Scan ICMP parallele: {0}.1 .. {0}.{1} (throttle {2})" -f $base, $MaxHosts, $Throttle))
    $lines.Add("")

    $targets = 1..$MaxHosts | ForEach-Object { "{0}.{1}" -f $base, $_ }
    $alive = New-Object System.Collections.Generic.List[string]
    $queue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())
    foreach ($t in $targets) { $null = $queue.Enqueue($t) }

    $pool = [runspacefactory]::CreateRunspacePool(1, $Throttle)
    $pool.Open()
    $pingExe = Join-Path $env:SystemRoot "System32\ping.exe"
    $scriptBlock = {
        param($ip, $exe)
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.Arguments = "-n 1 -w 200 `"$ip`""
        $psi.RedirectStandardOutput = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        $null = $p.StandardOutput.ReadToEnd()
        $null = $p.WaitForExit(2000)
        if ($p.ExitCode -eq 0) { return $ip }
        return $null
    }

    $running = @()
    while ($queue.Count -gt 0 -or $running.Count -gt 0) {
        while ($running.Count -lt $Throttle -and $queue.Count -gt 0) {
            $ip = $queue.Dequeue()
            $ps = [powershell]::Create().AddScript($scriptBlock).AddArgument($ip).AddArgument($pingExe)
            $ps.RunspacePool = $pool
            $running += [pscustomobject]@{ PS = $ps; Async = $ps.BeginInvoke() }
        }
        $done = @()
        foreach ($r in $running) {
            if ($r.Async.IsCompleted) {
                $result = $r.PS.EndInvoke($r.Async)
                $r.PS.Dispose()
                if ($result) { $alive.Add($result) | Out-Null }
                $done += $r
            }
        }
        $running = $running | Where-Object { $_ -notin $done }
        if ($running.Count -gt 0) { Start-Sleep -Milliseconds 40 }
    }
    $pool.Close()
    $pool.Dispose()

    if ($alive.Count -eq 0) {
        $lines.Add("Aucune reponse ICMP dans la plage scannee.")
    } else {
        $alive | Sort-Object {
            $p = $_.Split('.')
            [int]$p[3]
        } | ForEach-Object {
            $lines.Add(("  ALIVE  {0}" -f $_))
        }
    }
    return ($lines -join "`n")
}

function Invoke-WisoLan {
    param([int]$MaxHosts = 24)
    if ($MaxHosts -lt 1) { $MaxHosts = 1 }
    if ($MaxHosts -gt 32) { $MaxHosts = 32 }

    try {
        $ctx = Get-WisoLanSubnetContext
    } catch {
        return $_.Exception.Message
    }
    $base = $ctx.Base
    $gw = $ctx.Gateway

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(("Subnet: {0}.0/24 (interface {1})" -f $base, $ctx.Interface))
    $lines.Add(("Gateway: {0}" -f $gw))
    $lines.Add(("Scan ICMP: {0}.1 .. {0}.{1} (max {1} hotes)" -f $base, $MaxHosts))
    $lines.Add("")

    $alive = New-Object System.Collections.Generic.List[string]
    1..$MaxHosts | ForEach-Object {
        $target = "{0}.{1}" -f $base, $_
        if (Test-WisoPingHostOnce -Target $target) {
            $alive.Add($target) | Out-Null
        }
    }

    if ($alive.Count -eq 0) {
        $lines.Add("Aucune reponse ICMP dans la plage scannee.")
    } else {
        foreach ($h in $alive) {
            $lines.Add(("  ALIVE  {0}" -f $h))
        }
    }
    return ($lines -join "`n")
}
