$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$BuildScript = Join-Path $RepoRoot 'scripts/build-v2-runtime.ps1'
$ExePath = Join-Path $RepoRoot 'build/deadwire_v2_runtime.exe'

if (-not (Test-Path $BuildScript)) {
    throw "missing V2 runtime build script: $BuildScript"
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BuildScript
if ($LASTEXITCODE -ne 0) {
    throw "V2 runtime build script failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $ExePath)) {
    throw "missing V2 runtime executable: $ExePath"
}

& $ExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 runtime executable failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2build: ok'
