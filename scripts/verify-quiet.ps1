param(
    [int] $Port = 19093
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$BuildQuiet = Join-Path $PSScriptRoot 'build-win-accesslog-off.ps1'
$Exe = Join-Path $Root 'build\deadwire_accesslog_off.exe'
$Log = Join-Path $Root 'build\deadwire-quiet.log'
$Err = Join-Path $Root 'build\deadwire-quiet.err'

if (-not (Test-Path $BuildQuiet)) {
    throw "verify-quiet: missing build script: $BuildQuiet"
}

& $BuildQuiet -OutputExe $Exe
if ($LASTEXITCODE -ne 0) {
    throw 'verify-quiet: quiet build failed'
}

Remove-Item $Log, $Err -ErrorAction SilentlyContinue
$proc = Start-Process -FilePath $Exe -WorkingDirectory $Root -ArgumentList ([string] $Port) -PassThru -RedirectStandardOutput $Log -RedirectStandardError $Err

try {
    $ok = $false
    for ($i = 0; $i -lt 50; $i++) {
        try {
            $client = [Net.Sockets.TcpClient]::new()
            $client.ReceiveTimeout = 2000
            $client.SendTimeout = 2000
            $client.Connect('127.0.0.1', $Port)
            $stream = $client.GetStream()
            $req = [Text.Encoding]::ASCII.GetBytes("GET /health HTTP/1.0`r`nHost: 127.0.0.1`r`n`r`n")
            $stream.Write($req, 0, $req.Length)
            $buf = New-Object byte[] 2048
            $n = $stream.Read($buf, 0, $buf.Length)
            $text = [Text.Encoding]::UTF8.GetString($buf, 0, $n)
            $client.Close()
            if ($text -match '^HTTP/1\.0 200' -and $text -match 'deadwire: ok') {
                $ok = $true
                break
            }
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }

    if (-not $ok) {
        throw "verify-quiet failed: $Port"
    }
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
}

$stdout = if (Test-Path $Log) { Get-Content $Log -Raw } else { '' }
if ($stdout -notmatch 'DEADWIRE HTTPD') {
    throw 'verify-quiet: banner missing'
}

if ($stdout -match 'access ') {
    throw 'verify-quiet: access log was not disabled'
}

Write-Host "verify-quiet: ok $Port"
