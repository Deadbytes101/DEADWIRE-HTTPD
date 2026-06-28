$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Exe = Join-Path $Root 'build\deadwire.exe'
$Public = Join-Path $Root 'public'
$MaxFile = Join-Path $Public 'io-max.txt'
$TooLargeFile = Join-Path $Public 'io-too-large.txt'
$Log = Join-Path $Root 'build\deadwire-io.log'
$Err = Join-Path $Root 'build\deadwire-io.err'
$Port = 19096

if (-not (Test-Path $Exe)) {
    throw "verify-io: missing executable: $Exe"
}

Remove-Item $Log, $Err -ErrorAction SilentlyContinue
[IO.File]::WriteAllText($MaxFile, ('x' * 65536), [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($TooLargeFile, ('y' * 65537), [Text.UTF8Encoding]::new($false))

function Send-RawHttp {
    param([Parameter(Mandatory = $true)][string] $Request)

    $client = [System.Net.Sockets.TcpClient]::new()
    $client.ReceiveTimeout = 3000
    $client.SendTimeout = 3000
    $client.Connect('127.0.0.1', $Port)

    try {
        $stream = $client.GetStream()
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($Request)
        $stream.Write($bytes, 0, $bytes.Length)

        $buffer = New-Object byte[] 131072
        $builder = [System.Text.StringBuilder]::new()
        while ($true) {
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
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
        throw 'verify-io: malformed response without header terminator'
    }
    return @{ Headers = $parts[0]; Body = $parts[1]; Lines = $parts[0] -split "`r`n" }
}

function Assert-Status {
    param([hashtable] $Parts, [string] $Expected, [string] $Name)
    if ($Parts.Lines[0] -notmatch "^HTTP/1\.0 $Expected\b") {
        throw "verify-io: $Name expected HTTP $Expected, got: $($Parts.Lines[0])"
    }
}

function Assert-ContentLength {
    param([hashtable] $Parts, [int] $Expected, [string] $Name)
    $line = $Parts.Lines | Where-Object { $_ -match '^Content-Length: ' } | Select-Object -First 1
    if (-not $line) { throw "verify-io: $Name missing Content-Length" }
    $actual = [int]($line.Substring('Content-Length: '.Length))
    if ($actual -ne $Expected) {
        throw "verify-io: $Name expected Content-Length $Expected, got $actual"
    }
}

$proc = Start-Process -FilePath $Exe -ArgumentList @($Port.ToString()) -WorkingDirectory $Root -PassThru -RedirectStandardOutput $Log -RedirectStandardError $Err

try {
    $ready = $false
    for ($i = 0; $i -lt 50; $i++) {
        try {
            $parts = Split-Response (Send-RawHttp "GET /health HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n")
            if ($parts.Body.TrimEnd("`r", "`n") -eq 'deadwire: ok') { $ready = $true; break }
        }
        catch { Start-Sleep -Milliseconds 100 }
    }

    if (-not $ready) { throw 'verify-io: server did not become ready' }

    $parts = Split-Response (Send-RawHttp "GET /io-max.txt HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n")
    Assert-Status $parts '200' 'max file'
    Assert-ContentLength $parts 65536 'max file'
    if ($parts.Body.Length -ne 65536) { throw "verify-io: max file body length mismatch: $($parts.Body.Length)" }

    $parts = Split-Response (Send-RawHttp "GET /io-too-large.txt HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n")
    Assert-Status $parts '413' 'too large file'

    Write-Host 'verify-io: ok'
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
    Remove-Item $MaxFile, $TooLargeFile -ErrorAction SilentlyContinue
}
