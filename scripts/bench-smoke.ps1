param(
    [int] $Port = 19100,
    [int] $Requests = 256,
    [string] $Path = '/health',
    [int] $Rounds = 5
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Exe = Join-Path $Root 'build\deadwire.exe'
$Log = Join-Path $Root 'build\deadwire-bench.log'
$Err = Join-Path $Root 'build\deadwire-bench.err'

if (-not (Test-Path $Exe)) {
    throw "bench-smoke: missing executable: $Exe"
}

if ($Requests -lt 1) {
    throw 'bench-smoke: Requests must be >= 1'
}

if ($Rounds -lt 1) {
    throw 'bench-smoke: Rounds must be >= 1'
}

Remove-Item $Log, $Err -ErrorAction SilentlyContinue

function Send-One {
    param([string] $TargetPath)

    $client = [System.Net.Sockets.TcpClient]::new()
    $client.NoDelay = $true
    $client.ReceiveTimeout = 3000
    $client.SendTimeout = 3000
    $client.Connect('127.0.0.1', $Port)

    try {
        $stream = $client.GetStream()
        $request = "GET $TargetPath HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($request)
        $stream.Write($bytes, 0, $bytes.Length)

        $buffer = New-Object byte[] 65536
        $total = 0
        while ($true) {
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            $total += $read
        }

        return $total
    }
    finally {
        $client.Close()
    }
}

function Get-Median {
    param([double[]] $Values)

    $sorted = $Values | Sort-Object
    $count = $sorted.Count
    $mid = [int] [Math]::Floor($count / 2)

    if (($count % 2) -eq 1) {
        return [double] $sorted[$mid]
    }

    return ([double] $sorted[$mid - 1] + [double] $sorted[$mid]) / 2.0
}

function Run-Round {
    param([string] $TargetPath)

    [void] (Send-One $TargetPath)
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $bytesTotal = 0
    for ($i = 0; $i -lt $Requests; $i++) {
        $bytesTotal += Send-One $TargetPath
    }
    $sw.Stop()

    $seconds = [Math]::Max($sw.Elapsed.TotalSeconds, 0.000001)
    $rps = $Requests / $seconds
    $avgMs = ($seconds * 1000.0) / $Requests

    return [pscustomobject]@{
        Seconds = $seconds
        Rps = $rps
        AvgMs = $avgMs
        Bytes = $bytesTotal
    }
}

$proc = Start-Process -FilePath $Exe -ArgumentList @($Port.ToString()) -WorkingDirectory $Root -PassThru -RedirectStandardOutput $Log -RedirectStandardError $Err

try {
    $ready = $false
    for ($i = 0; $i -lt 50; $i++) {
        try {
            [void] (Send-One '/health')
            $ready = $true
            break
        }
        catch {
            Start-Sleep -Milliseconds 100
        }
    }

    if (-not $ready) {
        throw 'bench-smoke: server did not become ready'
    }

    $rows = @()
    for ($round = 1; $round -le $Rounds; $round++) {
        $result = Run-Round $Path
        $rows += $result
        Write-Host ('bench-smoke-round: path={0} round={1}/{2} requests={3} seconds={4:n3} rps={5:n2} avg_ms={6:n3} bytes={7}' -f $Path, $round, $Rounds, $Requests, $result.Seconds, $result.Rps, $result.AvgMs, $result.Bytes)
    }

    $rpsValues = [double[]] ($rows | ForEach-Object { $_.Rps })
    $avgValues = [double[]] ($rows | ForEach-Object { $_.AvgMs })
    $secondsValues = [double[]] ($rows | ForEach-Object { $_.Seconds })
    $bytesValues = [int[]] ($rows | ForEach-Object { $_.Bytes })

    $medianRps = Get-Median $rpsValues
    $medianAvgMs = Get-Median $avgValues
    $medianSeconds = Get-Median $secondsValues
    $minRps = ($rpsValues | Measure-Object -Minimum).Minimum
    $maxRps = ($rpsValues | Measure-Object -Maximum).Maximum
    $bytes = $bytesValues[0]

    Write-Host ('bench-smoke: path={0} rounds={1} requests={2} median_seconds={3:n3} median_rps={4:n2} median_avg_ms={5:n3} min_rps={6:n2} max_rps={7:n2} bytes={8}' -f $Path, $Rounds, $Requests, $medianSeconds, $medianRps, $medianAvgMs, $minRps, $maxRps, $bytes)
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
}
