param(
    [int] $Port = 19820,
    [string] $Path = '/health',
    [string] $ServerExePath = ''
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Exe = if ($ServerExePath) { $ServerExePath } else { Join-Path $Root 'build\deadwire.exe' }
$Log = Join-Path $Root 'build\deadwire-keepalive-probe.log'
$Err = Join-Path $Root 'build\deadwire-keepalive-probe.err'

function Read-ResponseOnStream {
    param(
        [Net.Sockets.NetworkStream] $Stream,
        [string] $RequestPath
    )

    $req = [Text.Encoding]::ASCII.GetBytes("GET $RequestPath HTTP/1.1`r`nHost: 127.0.0.1`r`nConnection: keep-alive`r`n`r`n")
    $Stream.Write($req, 0, $req.Length)

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

    return @{ Bytes = $used; Header = $headerText }
}

if (-not (Test-Path $Exe)) {
    throw "probe-keepalive: missing server executable: $Exe"
}

Remove-Item $Log, $Err -ErrorAction SilentlyContinue
$proc = Start-Process -FilePath $Exe -WorkingDirectory $Root -ArgumentList ([string] $Port) -PassThru -RedirectStandardOutput $Log -RedirectStandardError $Err

try {
    $ready = $false
    for ($i = 0; $i -lt 50; $i++) {
        try {
            $client = [Net.Sockets.TcpClient]::new()
            $client.ReceiveTimeout = 1000
            $client.SendTimeout = 1000
            $client.Connect('127.0.0.1', $Port)
            $stream = $client.GetStream()
            [void] (Read-ResponseOnStream -Stream $stream -RequestPath '/health')
            $client.Close()
            $ready = $true
            break
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }

    if (-not $ready) {
        throw 'probe-keepalive: server did not become ready'
    }

    $client = [Net.Sockets.TcpClient]::new()
    $client.ReceiveTimeout = 2000
    $client.SendTimeout = 2000
    $client.Connect('127.0.0.1', $Port)
    $stream = $client.GetStream()

    $first = Read-ResponseOnStream -Stream $stream -RequestPath $Path

    try {
        $second = Read-ResponseOnStream -Stream $stream -RequestPath $Path
        $client.Close()
        Write-Host ('probe-keepalive: supported path={0} first_bytes={1} second_bytes={2}' -f $Path, $first.Bytes, $second.Bytes)
    } catch {
        $client.Close()
        Write-Host ('probe-keepalive: close-after-response confirmed path={0} first_bytes={1}' -f $Path, $first.Bytes)
    }
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
}
