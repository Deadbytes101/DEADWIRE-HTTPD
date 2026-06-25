$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Exe = Join-Path $Root 'build\deadwire.exe'
$Log = Join-Path $Root 'build\deadwire.log'
$Err = Join-Path $Root 'build\deadwire.err'

if (-not (Test-Path $Exe)) {
    throw "verify: missing executable: $Exe"
}

Remove-Item $Log, $Err -ErrorAction SilentlyContinue

function Send-RawHttp {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Request
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    $client.ReceiveTimeout = 2000
    $client.SendTimeout = 2000
    $client.Connect('127.0.0.1', 18080)

    try {
        $stream = $client.GetStream()
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($Request)
        $stream.Write($bytes, 0, $bytes.Length)

        $buffer = New-Object byte[] 65536
        $builder = [System.Text.StringBuilder]::new()

        while ($true) {
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) {
                break
            }
            [void] $builder.Append([System.Text.Encoding]::UTF8.GetString($buffer, 0, $read))
        }

        return $builder.ToString()
    }
    finally {
        $client.Close()
    }
}

function Assert-Status {
    param(
        [string] $Response,
        [string] $Expected
    )

    $firstLine = ($Response -split "`r?`n", 2)[0]
    if ($firstLine -notmatch "^HTTP/1\.0 $Expected\b") {
        throw "verify: expected HTTP $Expected, got: $firstLine"
    }
}

function Assert-Header {
    param(
        [string] $Response,
        [string] $ExpectedHeader
    )

    $headers = ($Response -split "`r`n`r`n", 2)[0]
    if ($headers -notmatch [regex]::Escape($ExpectedHeader)) {
        throw "verify: missing header: $ExpectedHeader"
    }
}

function Assert-LogContains {
    param(
        [string] $LogText,
        [string] $ExpectedLine
    )

    if ($LogText -notmatch [regex]::Escape($ExpectedLine)) {
        throw "verify: missing access log line: $ExpectedLine"
    }
}

function Get-Body {
    param([string] $Response)
    $parts = $Response -split "`r`n`r`n", 2
    if ($parts.Count -ne 2) {
        throw "verify: malformed response without header terminator"
    }
    return $parts[1]
}

$proc = Start-Process -FilePath $Exe -WorkingDirectory $Root -PassThru -RedirectStandardOutput $Log -RedirectStandardError $Err

try {
    $ready = $false
    for ($i = 0; $i -lt 50; $i++) {
        try {
            $response = Send-RawHttp "GET /health HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
            if ((Get-Body $response).TrimEnd("`r", "`n") -eq 'deadwire: ok') {
                $ready = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 100
        }
    }

    if (-not $ready) {
        throw 'verify: server did not become ready'
    }

    $response = Send-RawHttp "GET /health HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
    Assert-Status $response '200'
    Assert-Header $response 'Content-Type: text/plain; charset=utf-8'
    if ((Get-Body $response).TrimEnd("`r", "`n") -ne 'deadwire: ok') {
        throw 'verify: /health body mismatch'
    }

    $response = Send-RawHttp "GET / HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
    Assert-Status $response '200'
    Assert-Header $response 'Content-Type: text/html; charset=utf-8'

    $response = Send-RawHttp "GET /hello.txt HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
    Assert-Status $response '200'
    Assert-Header $response 'Content-Type: text/plain; charset=utf-8'
    if ((Get-Body $response).TrimEnd("`r", "`n") -ne 'hello from deadwire') {
        throw 'verify: /hello.txt body mismatch'
    }

    $response = Send-RawHttp "GET /style.css HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
    Assert-Status $response '200'
    Assert-Header $response 'Content-Type: text/css; charset=utf-8'

    $response = Send-RawHttp "POST / HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
    Assert-Status $response '405'

    $response = Send-RawHttp "GET /../../etc/passwd HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
    Assert-Status $response '403'

    $response = Send-RawHttp "GET /missing.txt HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
    Assert-Status $response '404'

    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }

    $logText = Get-Content -Raw $Log
    Assert-LogContains $logText 'access 200 /health'
    Assert-LogContains $logText 'access 200 static'
    Assert-LogContains $logText 'access 405 method'
    Assert-LogContains $logText 'access 403 forbidden'
    Assert-LogContains $logText 'access 404 not-found'

    Write-Host 'verify: ok'
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
}
