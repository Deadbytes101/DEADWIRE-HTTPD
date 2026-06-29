param(
    [int] $Port = 19840,
    [int] $Requests = 32768,
    [int] $Rounds = 5,
    [string] $Path = '/health'
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Build = Join-Path $PSScriptRoot 'build-win-keepalive-experimental.ps1'
$Exe = Join-Path $Root 'build\deadwire_keepalive_experimental.exe'
$Log = Join-Path $Root 'build\deadwire-keepalive-bench.log'
$Err = Join-Path $Root 'build\deadwire-keepalive-bench.err'

function Read-OneResponse {
    param(
        [Net.Sockets.NetworkStream] $Stream
    )

    $buf = New-Object byte[] 131072
    $used = 0
    $headerEnd = -1

    while ($headerEnd -lt 0) {
        $n = $Stream.Read($buf, $used, ($buf.Length - $used))
        if ($n -le 0) {
            throw 'connection closed before response header'
        }
        $used += $n
        $text = [Text.Encoding]::ASCII.GetString($buf, 0, $used)
        $headerEnd = $text.IndexOf("`r`n`r`n")
        if ($used -ge $buf.Length) {
            throw 'response too large'
        }
    }

    $headerText = [Text.Encoding]::ASCII.GetString($buf, 0, $headerEnd + 4)
    $match = [regex]::Match($headerText, 'Content-Length: ([0-9]+)')
    if (-not $match.Success) {
        throw 'missing Content-Length'
    }

    $contentLength = [int] $match.Groups[1].Value
    $target = ($headerEnd + 4) + $contentLength

    while ($used -lt $target) {
        $n = $Stream.Read($buf, $used, ($target - $used))
        if ($n -le 0) {
            throw 'connection closed before response body was complete'
        }
        $used += $n
        if ($used -ge $buf.Length) {
            throw 'response too large'
        }
    }

    return $used
}

function Run-Round {
    param(
        [string] $RequestPath,
        [int] $Count
    )

    $client = [Net.Sockets.TcpClient]::new()
    $client.ReceiveTimeout = 5000
    $client.SendTimeout = 5000
    $client.Connect('127.0.0.1', $Port)
    $stream = $client.GetStream()
    $req = [Text.Encoding]::ASCII.GetBytes("GET $RequestPath HTTP/1.1`r`nHost: 127.0.0.1`r`nConnection: keep-alive`r`n`r`n")
    $bytes = [Int64] 0
    $sw = [Diagnostics.Stopwatch]::StartNew()

    try {
        for ($i = 0; $i -lt $Count; $i++) {
            $stream.Write($req, 0, $req.Length)
            $bytes += Read-OneResponse -Stream $stream
        }
    }
    finally {
        $sw.Stop()
        $client.Close()
    }

    $seconds = [Math]::Max($sw.Elapsed.TotalSeconds, 0.000001)
    return [pscustomobject]@{
        Seconds = $seconds
        Rps = [double] $Count / $seconds
        AvgMs = ($seconds * 1000.0) / [double] $Count
        Bytes = $bytes
    }
}

if ($Requests -lt 1) {
    throw 'bench-keepalive-experimental: Requests must be >= 1'
}
if ($Rounds -lt 1) {
    throw 'bench-keepalive-experimental: Rounds must be >= 1'
}
if (-not $Path.StartsWith('/')) {
    throw 'bench-keepalive-experimental: Path must start with /'
}

& $Build -OutputExe $Exe
if ($LASTEXITCODE -ne 0) {
    throw 'bench-keepalive-experimental: build failed'
}

Remove-Item $Log, $Err -ErrorAction SilentlyContinue
$proc = Start-Process -FilePath $Exe -WorkingDirectory $Root -ArgumentList ([string] $Port) -PassThru -RedirectStandardOutput $Log -RedirectStandardError $Err

try {
    $ready = $false
    for ($i = 0; $i -lt 50; $i++) {
        try {
            [void] (Run-Round -RequestPath '/health' -Count 1)
            $ready = $true
            break
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }

    if (-not $ready) {
        throw 'bench-keepalive-experimental: server did not become ready'
    }

    Write-Host ("keepalive-bench: mode=experimental path={0} requests={1} rounds={2}" -f $Path, $Requests, $Rounds)
    $roundsOut = @()
    for ($round = 1; $round -le $Rounds; $round++) {
        $r = Run-Round -RequestPath $Path -Count $Requests
        $roundsOut += $r
        Write-Host ("keepalive-bench-round: path={0} round={1}/{2} requests={3} seconds={4:n3} rps={5:n2} avg_ms={6:n3} bytes={7}" -f $Path, $round, $Rounds, $Requests, $r.Seconds, $r.Rps, $r.AvgMs, $r.Bytes)
    }

    $ordered = $roundsOut | Sort-Object Seconds
    $median = $ordered[[int] [Math]::Floor($Rounds / 2)]
    $minRps = ($roundsOut | Measure-Object Rps -Minimum).Minimum
    $maxRps = ($roundsOut | Measure-Object Rps -Maximum).Maximum

    Write-Host ("keepalive-bench: path={0} rounds={1} requests={2} median_seconds={3:n3} median_rps={4:n2} median_avg_ms={5:n3} min_rps={6:n2} max_rps={7:n2} bytes={8}" -f $Path, $Rounds, $Requests, $median.Seconds, $median.Rps, $median.AvgMs, $minRps, $maxRps, $median.Bytes)
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
}
