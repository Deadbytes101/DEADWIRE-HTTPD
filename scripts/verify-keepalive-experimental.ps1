param(
    [int] $PortBase = 19860
)

$ErrorActionPreference = 'Stop'

$Build = Join-Path $PSScriptRoot 'build-win-keepalive-experimental.ps1'
$Matrix = Join-Path $PSScriptRoot 'probe-keepalive-experimental-matrix.ps1'

if (-not (Test-Path $Build)) {
    throw "verify-keepalive-experimental: missing build script: $Build"
}
if (-not (Test-Path $Matrix)) {
    throw "verify-keepalive-experimental: missing matrix probe: $Matrix"
}

& $Build
if ($LASTEXITCODE -ne 0) {
    throw 'verify-keepalive-experimental: build failed'
}

& $Matrix -PortBase $PortBase
if ($LASTEXITCODE -ne 0) {
    throw 'verify-keepalive-experimental: matrix probe failed'
}

Write-Host "verify-keepalive-experimental: ok port_base=$PortBase"
