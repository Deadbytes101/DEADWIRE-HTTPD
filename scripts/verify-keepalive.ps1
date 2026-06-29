param(
    [int] $PortBase = 19870
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Build = Join-Path $PSScriptRoot 'build-win-keepalive.ps1'
$Probe = Join-Path $PSScriptRoot 'probe-keepalive.ps1'
$Exe = Join-Path $Root 'build\deadwire_keepalive.exe'
$Paths = @('/health', '/hello.txt', '/missing-bench.txt', '/')

if (-not (Test-Path $Build)) {
    throw "verify-keepalive: missing build script: $Build"
}
if (-not (Test-Path $Probe)) {
    throw "verify-keepalive: missing probe script: $Probe"
}

& $Build -OutputExe $Exe
if ($LASTEXITCODE -ne 0) {
    throw 'verify-keepalive: build failed'
}

Write-Host 'verify-keepalive: matrix begin'
for ($i = 0; $i -lt $Paths.Count; $i++) {
    $path = $Paths[$i]
    $port = $PortBase + $i
    & $Probe -Port $port -Path $path -ServerExePath $Exe
    if ($LASTEXITCODE -ne 0) {
        throw "verify-keepalive: probe failed for $path"
    }
}
Write-Host "verify-keepalive: ok port_base=$PortBase"
