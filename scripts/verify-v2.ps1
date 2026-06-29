$ErrorActionPreference = 'Stop'

function Check-Status {
    param([string]$Step)
    if ($global:LASTEXITCODE -ne 0) {
        Write-Error "$Step returned $global:LASTEXITCODE"
    }
}

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $RepoRoot
try {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-runtime-boundary.ps1
    Check-Status 'verify-runtime-boundary'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-runtime-source-map.ps1
    Check-Status 'verify-runtime-source-map'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-runtime-request-boundary.ps1
    Check-Status 'verify-runtime-request-boundary'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2-triple-threading.ps1
    Check-Status 'verify-v2-triple-threading'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2q.ps1
    Check-Status 'verify-v2q'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2-worker-context.ps1
    Check-Status 'verify-v2-worker-context'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2lane.ps1
    Check-Status 'verify-v2lane'

    make verify
    Check-Status 'make verify'

    Write-Output 'verify-v2: ok'
}
finally {
    Pop-Location
}
