param(
    [int] $PortBase = 19830
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Build = Join-Path $PSScriptRoot 'build-win-keepalive-experimental.ps1'
$Probe = Join-Path $PSScriptRoot 'probe-keepalive.ps1'
$Exe = Join-Path $Root 'build\deadwire_keepalive_experimental.exe'
$Paths = @('/health', '/hello.txt', '/missing-bench.txt', '/')

if (-not (Test-Path $Build)) {
    throw "probe-keepalive-experimental-matrix: missing build script: $Build"
}
if (-not (Test-Path $Probe)) {
    throw "probe-keepalive-experimental-matrix: missing probe script: $Probe"
}

& $Build -OutputExe $Exe
if ($LASTEXITCODE -ne 0) {
    throw 'probe-keepalive-experimental-matrix: build failed'
}

Write-Host 'probe-keepalive-experimental-matrix: begin'
for ($i = 0; $i -lt $Paths.Count; $i++) {
    $path = $Paths[$i]
    $port = $PortBase + $i
    & $Probe -Port $port -Path $path -ServerExePath $Exe
    if ($LASTEXITCODE -ne 0) {
        throw "probe-keepalive-experimental-matrix: probe failed for $path"
    }
}
Write-Host 'probe-keepalive-experimental-matrix: done'
