$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Exe = Join-Path $Root 'build\deadwire.exe'
$Log = Join-Path $Root 'build\deadwire-winpath.log'
$Err = Join-Path $Root 'build\deadwire-winpath.err'
$Port = 19095

if (-not (Test-Path $Exe)) {
    throw "verify-winpath: missing executable: $Exe"
}

Remove-Item $Log, $Err -ErrorAction SilentlyContinue

function Send-RawHttp {
    param([Parameter(Mandatory = $true)][string] $Request)

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
            if ($read -le 0) { break }
            [void] $builder.Append([System.Text.Encoding]::UTF8.GetString($buffer, 0, $read))
        }
        return $builder.ToString()
    }
    finally {
        $client.Close()
    }
}

function Assert-Status {
    param([string] $Response, [string] $Expected, [string] $Name)
    $firstLine = ($Response -split "`r?`n", 2)[0]
    if ($firstLine -notmatch "^HTTP/1\.0 $Expected\b") {
        throw "verify-winpath: $Name expected HTTP $Expected, got: $firstLine"
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
        throw 'verify-winpath: server did not become ready'
    }

    $paths = @('/.', '/hello.txt.')
    foreach ($code in @(58, 42, 63, 34, 60, 62, 124)) {
        $paths += ('/bad' + [char]$code + 'name')
    }

    foreach ($path in $paths) {
        $response = Send-RawHttp "GET $path HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n"
        Assert-Status $response '403' $path
    }

    Write-Host 'verify-winpath: ok'
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
}
