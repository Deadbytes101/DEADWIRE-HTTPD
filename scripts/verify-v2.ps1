$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $RepoRoot
try {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-runtime-boundary.ps1
    make verify
    Write-Output 'verify-v2: ok'
}
finally {
    Pop-Location
}
