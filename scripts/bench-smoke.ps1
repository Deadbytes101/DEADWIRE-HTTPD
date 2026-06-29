$ErrorActionPreference = 'Stop'

param(
    [int] $Port = 19100,
    [int] $Requests = 256,
    [string] $Path = '/health'
)

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

    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $bytesTotal = 0
    for ($i = 0; $i -lt $Requests; $i++) {
        $bytesTotal += Send-One $Path
    }
    $sw.Stop()

    $seconds = [Math]::Max($sw.Elapsed.TotalSeconds, 0.000001)
    $rps = $Requests / $seconds
    $avgMs = ($seconds * 1000.0) / $Requests

    Write-Host ('bench-smoke: path={0} requests={1} seconds={2:n3} rps={3:n2} avg_ms={4:n3} bytes={5}' -f $Path, $Requests, $seconds, $rps, $avgMs, $bytesTotal)
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
}
