param(
    [int] $Port = 19821,
    [string] $Path = '/health'
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Build = Join-Path $PSScriptRoot 'build-win-keepalive-experimental.ps1'
$Probe = Join-Path $PSScriptRoot 'probe-keepalive.ps1'
$Exe = Join-Path $Root 'build\deadwire_keepalive_experimental.exe'

if (-not (Test-Path $Build)) {
    throw "probe-keepalive-experimental: missing build script: $Build"
}
if (-not (Test-Path $Probe)) {
    throw "probe-keepalive-experimental: missing probe script: $Probe"
}

& $Build -OutputExe $Exe
if ($LASTEXITCODE -ne 0) {
    throw 'probe-keepalive-experimental: build failed'
}

& $Probe -Port $Port -Path $Path -ServerExePath $Exe
if ($LASTEXITCODE -ne 0) {
    throw 'probe-keepalive-experimental: probe failed'
}
