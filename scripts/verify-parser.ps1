$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Exe = Join-Path $Root 'build\deadwire.exe'
$Log = Join-Path $Root 'build\deadwire-parser.log'
$Err = Join-Path $Root 'build\deadwire-parser.err'
$Port = 19093

if (-not (Test-Path $Exe)) {
    throw "verify-parser: missing executable: $Exe"
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

function Assert-Status {
    param(
        [string] $Response,
        [string] $Expected,
        [string] $Name
    )

    $firstLine = ($Response -split "`r?`n", 2)[0]
    if ($firstLine -notmatch "^HTTP/1\.0 $Expected\b") {
        throw "verify-parser: $Name expected HTTP $Expected, got: $firstLine"
    }
}

function Assert-LogContains {
    param(
        [string] $LogText,
        [string] $ExpectedLine
    )

    if ($LogText -notmatch [regex]::Escape($ExpectedLine)) {
        throw "verify-parser: missing log line: $ExpectedLine"
    }
}

$proc = Start-Process -FilePath $Exe -ArgumentList @($Port.ToString()) -WorkingDirectory $Root -PassThru -RedirectStandardOutput $Log -RedirectStandardError $Err

try {
    $ready = $false
    for ($i = 0; $i -lt 50; $i++) {
        try {
            $response = Send-RawHttp "GET /health HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
            if (($response -split "`r`n`r`n", 2)[1].TrimEnd("`r", "`n") -eq 'deadwire: ok') {
                $ready = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 100
        }
    }

    if (-not $ready) {
        throw 'verify-parser: server did not become ready'
    }

    $cases = @(
        @{ Name = 'http11-health'; Request = "GET /health HTTP/1.1`r`nHost: 127.0.0.1`r`n`r`n"; Status = '200' },
        @{ Name = 'bad-version-token'; Request = "GET /health BAD/1.0`r`nHost: 127.0.0.1`r`n`r`n"; Status = '400' },
        @{ Name = 'bad-version-number'; Request = "GET /health HTTP/9.9`r`nHost: 127.0.0.1`r`n`r`n"; Status = '400' },
        @{ Name = 'bad-version-trailer'; Request = "GET /health HTTP/1.0X`r`nHost: 127.0.0.1`r`n`r`n"; Status = '400' },
        @{ Name = 'double-space-path'; Request = "GET  /health HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"; Status = '400' },
        @{ Name = 'raw-percent-path'; Request = "GET /bad%2fpath HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"; Status = '403' },
        @{ Name = 'backslash-path'; Request = "GET /bad\path HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"; Status = '403' }
    )

    foreach ($case in $cases) {
        $response = Send-RawHttp $case.Request
        Assert-Status $response $case.Status $case.Name
    }

    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }

    $logText = Get-Content -Raw $Log
    Assert-LogContains $logText 'access status=200 route=/health'
    Assert-LogContains $logText 'access status=400 reason=bad-request'
    Assert-LogContains $logText 'access status=403 reason=forbidden'

    Write-Host 'verify-parser: ok'
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
}
