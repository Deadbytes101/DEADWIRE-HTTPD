param(
    [string] $SourceAsm = '',
    [string] $OutputExe = ''
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Build = Join-Path $PSScriptRoot 'build-win-keepalive-experimental.ps1'
$Exe = if ($OutputExe) { $OutputExe } else { Join-Path $Root 'build\deadwire_keepalive.exe' }

if (-not (Test-Path $Build)) {
    throw "build-win-keepalive: missing build script: $Build"
}

$argsList = @('-OutputExe', $Exe)
if ($SourceAsm) {
    $argsList += @('-SourceAsm', $SourceAsm)
}

& $Build @argsList
if ($LASTEXITCODE -ne 0) {
    throw 'build-win-keepalive: build failed'
}

Write-Host "build-win-keepalive: ok $Exe"
