$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Exe = Join-Path $Root 'build\deadwire.exe'
$Log = Join-Path $Root 'build\deadwire-response.log'
$Err = Join-Path $Root 'build\deadwire-response.err'
$Port = 19094

if (-not (Test-Path $Exe)) {
    throw "verify-response: missing executable: $Exe"
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
    $client.Connect('127.0.0.1', $Port)

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

function Split-Response {
    param([string] $Response)

    $parts = $Response -split "`r`n`r`n", 2
    if ($parts.Count -ne 2) {
        throw 'verify-response: malformed response without header terminator'
    }

    return @{
        Headers = $parts[0]
        Body = $parts[1]
        Lines = $parts[0] -split "`r`n"
    }
}

function Assert-Status {
    param(
        [hashtable] $Parts,
        [string] $Expected,
        [string] $Name
    )

    if ($Parts.Lines[0] -notmatch "^HTTP/1\.0 $Expected\b") {
        throw "verify-response: $Name expected HTTP $Expected, got: $($Parts.Lines[0])"
    }
}

function Assert-HeaderOrder {
    param(
        [hashtable] $Parts,
        [string] $Name
    )

    if ($Parts.Lines.Count -lt 4) {
        throw "verify-response: $Name missing required headers"
    }
    if ($Parts.Lines[1] -ne 'Connection: close') {
        throw "verify-response: $Name bad header[1]: $($Parts.Lines[1])"
    }
    if ($Parts.Lines[2] -notmatch '^Content-Type: ') {
        throw "verify-response: $Name bad header[2]: $($Parts.Lines[2])"
    }
    if ($Parts.Lines[3] -notmatch '^Content-Length: [0-9]+$') {
        throw "verify-response: $Name bad header[3]: $($Parts.Lines[3])"
    }
}

function Assert-ContentLength {
    param(
        [hashtable] $Parts,
        [int] $Expected,
        [string] $Name
    )

    $line = $Parts.Lines | Where-Object { $_ -match '^Content-Length: ' } | Select-Object -First 1
    if (-not $line) {
        throw "verify-response: $Name missing Content-Length"
    }

    $actual = [int]($line.Substring('Content-Length: '.Length))
    if ($actual -ne $Expected) {
        throw "verify-response: $Name expected Content-Length $Expected, got $actual"
    }
}

function Assert-NoBody {
    param(
        [hashtable] $Parts,
        [string] $Name
    )

    if ($Parts.Body.Length -ne 0) {
        throw "verify-response: $Name returned body length $($Parts.Body.Length)"
    }
}

$proc = Start-Process -FilePath $Exe -ArgumentList @($Port.ToString()) -WorkingDirectory $Root -PassThru -RedirectStandardOutput $Log -RedirectStandardError $Err

try {
    $ready = $false
    for ($i = 0; $i -lt 50; $i++) {
        try {
            $response = Send-RawHttp "GET /health HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
            $parts = Split-Response $response
            if ($parts.Body.TrimEnd("`r", "`n") -eq 'deadwire: ok') {
                $ready = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 100
        }
    }

    if (-not $ready) {
        throw 'verify-response: server did not become ready'
    }

    $cases = @(
        @{ Name = 'HEAD /health'; Request = "HEAD /health HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"; Status = '200'; Length = 13 },
        @{ Name = 'HEAD /missing'; Request = "HEAD /missing.txt HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"; Status = '404'; Length = 14 },
        @{ Name = 'HEAD traversal'; Request = "HEAD /../../etc/passwd HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"; Status = '403'; Length = 14 },
        @{ Name = 'HEAD percent'; Request = "HEAD /bad%2fpath HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"; Status = '403'; Length = 14 }
    )

    foreach ($case in $cases) {
        $response = Send-RawHttp $case.Request
        $parts = Split-Response $response
        Assert-Status $parts $case.Status $case.Name
        Assert-HeaderOrder $parts $case.Name
        Assert-ContentLength $parts $case.Length $case.Name
        Assert-NoBody $parts $case.Name
    }

    $longPath = '/' + ('a' * 501)
    $response = Send-RawHttp "HEAD $longPath HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
    $parts = Split-Response $response
    Assert-Status $parts '414' 'HEAD uri-too-long'
    Assert-HeaderOrder $parts 'HEAD uri-too-long'
    Assert-ContentLength $parts 17 'HEAD uri-too-long'
    Assert-NoBody $parts 'HEAD uri-too-long'

    $response = Send-RawHttp "POST /health HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
    $parts = Split-Response $response
    Assert-Status $parts '405' 'POST /health'
    Assert-HeaderOrder $parts 'POST /health'
    Assert-ContentLength $parts 23 'POST /health'
    if ($parts.Body.Length -ne 23) {
        throw "verify-response: POST /health body length mismatch: $($parts.Body.Length)"
    }

    Write-Host 'verify-response: ok'
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
}
