param(
    [int] $Port = 19200,
    [int] $Requests = 1024,
    [string] $Path = '/health',
    [int] $Rounds = 5
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ServerExe = Join-Path $Root 'build\deadwire.exe'
$BenchSrc = Join-Path $Root 'tools\deadwire_bench.c'
$BenchExe = Join-Path $Root 'build\deadwire_bench.exe'
$Log = Join-Path $Root 'build\deadwire-native-bench.log'
$Err = Join-Path $Root 'build\deadwire-native-bench.err'

if (-not (Test-Path $ServerExe)) {
    throw "bench-native: missing server executable: $ServerExe"
}

if (-not (Test-Path $BenchSrc)) {
    throw "bench-native: missing bench source: $BenchSrc"
}

if ($Requests -lt 1) {
    throw 'bench-native: Requests must be >= 1'
}

if ($Rounds -lt 1) {
    throw 'bench-native: Rounds must be >= 1'
}

$cc = if ($env:CC) { $env:CC } else { 'cc' }

& $cc -O2 -std=c99 -Wall -Wextra -o $BenchExe $BenchSrc -lws2_32
if ($LASTEXITCODE -ne 0) {
    throw "bench-native: failed to compile native bench client with $cc"
}

Remove-Item $Log, $Err -ErrorAction SilentlyContinue

$proc = Start-Process -FilePath $ServerExe -ArgumentList @($Port.ToString()) -WorkingDirectory $Root -PassThru -RedirectStandardOutput $Log -RedirectStandardError $Err

try {
    $ready = $false
    for ($i = 0; $i -lt 50; $i++) {
        & $BenchExe 127.0.0.1 $Port /health 1 1 *> $null
        if ($LASTEXITCODE -eq 0) {
            $ready = $true
            break
        }
        Start-Sleep -Milliseconds 100
    }

    if (-not $ready) {
        throw 'bench-native: server did not become ready'
    }

    & $BenchExe 127.0.0.1 $Port $Path $Requests $Rounds
    if ($LASTEXITCODE -ne 0) {
        throw "bench-native: native bench failed for path $Path"
    }
}
finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit()
    }
}
