param(
    [string] $ServerExePath = '',
    [string[]] $ServerArgs = @(),
    [string] $HostName = '127.0.0.1',
    [int] $Port = 8080,
    [string] $Path = '/health',
    [int] $Requests = 1024,
    [int] $Rounds = 5,
    [int] $Warmup = 16,
    [string] $ReadyPath = '/health',
    [int] $StartupTimeoutMs = 5000,
    [string] $WorkingDirectory = '',
    [switch] $KeepAlive,
    [switch] $ExistingServer
)

$ErrorActionPreference = 'Stop'
if ($Port -lt 1 -or $Port -gt 65535) { throw 'bench-external-server: Port must be 1..65535' }
if ($Requests -lt 1) { throw 'bench-external-server: Requests must be >= 1' }
if ($Rounds -lt 1) { throw 'bench-external-server: Rounds must be >= 1' }
if ($Warmup -lt 0) { throw 'bench-external-server: Warmup must be >= 0' }
if ($StartupTimeoutMs -lt 1) { throw 'bench-external-server: StartupTimeoutMs must be >= 1' }
if ($Path[0] -ne '/' -and $Path -ne '--head-health') { throw 'bench-external-server: Path must start with / or be --head-health' }
if ($ReadyPath[0] -ne '/' -and $ReadyPath -ne '--head-health') { throw 'bench-external-server: ReadyPath must start with / or be --head-health' }
if ($KeepAlive -and $Path -eq '--head-health') { throw 'bench-external-server: KeepAlive requires a normal GET path' }

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$BenchSrc = Join-Path $Root 'tools/deadwire_bench.c'
$BenchExe = Join-Path $Root 'build/deadwire_external_bench.exe'
$BuildDir = Join-Path $Root 'build'
if (!(Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir | Out-Null }
if (!(Test-Path $BenchSrc)) { throw "bench-external-server: missing bench source: $BenchSrc" }

$cc = if ($env:CC) { $env:CC } else { 'cc' }
& $cc -O2 -std=c99 -Wall -Wextra -o $BenchExe $BenchSrc -lws2_32
if ($LASTEXITCODE) { throw "bench-external-server: failed to compile native bench client with $cc" }

$ServerProcess = $null
$RunDir = if ($WorkingDirectory) { Resolve-Path $WorkingDirectory } else { $Root }
if (!$ExistingServer) {
    if (!$ServerExePath) { throw 'bench-external-server: ServerExePath is required unless ExistingServer is set' }
    if (!(Test-Path $ServerExePath)) { throw "bench-external-server: missing server executable: $ServerExePath" }
    $ResolvedServerExe = Resolve-Path $ServerExePath
    $Log = Join-Path $BuildDir 'deadwire-external-bench.log'
    $Err = Join-Path $BuildDir 'deadwire-external-bench.err'
    Remove-Item $Log, $Err -ErrorAction SilentlyContinue
    $ServerProcess = Start-Process -FilePath $ResolvedServerExe -ArgumentList $ServerArgs -WorkingDirectory $RunDir -PassThru -RedirectStandardOutput $Log -RedirectStandardError $Err
}

try {
    $Ready = $false
    $Attempts = [Math]::Max(1, [int]($StartupTimeoutMs / 100))
    for ($I = 0; $I -lt $Attempts; $I++) {
        & $BenchExe $HostName $Port $ReadyPath 1 1 *> $null
        if ($LASTEXITCODE -eq 0) { $Ready = $true; break }
        Start-Sleep -Milliseconds 100
    }
    if (!$Ready) { throw 'bench-external-server: server did not become ready' }

    if ($Warmup -gt 0) {
        if ($KeepAlive) {
            & $BenchExe $HostName $Port $Path $Warmup 1 --keepalive *> $null
        } else {
            & $BenchExe $HostName $Port $Path $Warmup 1 *> $null
        }
        if ($LASTEXITCODE) { throw "bench-external-server: warmup failed for path $Path" }
    }

    if ($KeepAlive) {
        & $BenchExe $HostName $Port $Path $Requests $Rounds --keepalive
    } else {
        & $BenchExe $HostName $Port $Path $Requests $Rounds
    }
    if ($LASTEXITCODE) { throw "bench-external-server: benchmark failed for path $Path" }
}
finally {
    if ($ServerProcess -and !$ServerProcess.HasExited) {
        Stop-Process -Id $ServerProcess.Id -Force
        $ServerProcess.WaitForExit()
    }
}
