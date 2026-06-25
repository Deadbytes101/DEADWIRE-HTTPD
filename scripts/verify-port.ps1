param(
    [int] $Port = 19090
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Exe = Join-Path $Root 'build\deadwire.exe'
$Log = Join-Path $Root 'build\deadwire-port.log'
$Err = Join-Path $Root 'build\deadwire-port.err'

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
            if ($text -match '^HTTP/1\.0 200' -and $text -match 'deadwire: ok') { $ok = $true; break }
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }
    if (-not $ok) { throw "verify-port failed: $Port" }
    Write-Host "verify-port: ok $Port"
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
}
