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

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2entry.ps1
    Check-Status 'verify-v2entry'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2flow.ps1
    Check-Status 'verify-v2flow'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2spawn.ps1
    Check-Status 'verify-v2spawn'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2set.ps1
    Check-Status 'verify-v2set'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2handle.ps1
    Check-Status 'verify-v2handle'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2join.ps1
    Check-Status 'verify-v2join'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2run.ps1
    Check-Status 'verify-v2run'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2boot.ps1
    Check-Status 'verify-v2boot'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2live.ps1
    Check-Status 'verify-v2live'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2liveclose.ps1
    Check-Status 'verify-v2liveclose'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2livecycle.ps1
    Check-Status 'verify-v2livecycle'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2liveprobe.ps1
    Check-Status 'verify-v2liveprobe'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2accept.ps1
    Check-Status 'verify-v2accept'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2acceptprobe.ps1
    Check-Status 'verify-v2acceptprobe'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2bridge.ps1
    Check-Status 'verify-v2bridge'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2bridgeprobe.ps1
    Check-Status 'verify-v2bridgeprobe'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2step.ps1
    Check-Status 'verify-v2step'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2stepprobe.ps1
    Check-Status 'verify-v2stepprobe'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2tickproof.ps1
    Check-Status 'verify-v2tickproof'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2bound.ps1
    Check-Status 'verify-v2bound'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2mode.ps1
    Check-Status 'verify-v2mode'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2build.ps1
    Check-Status 'verify-v2build'

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2make.ps1
    Check-Status 'verify-v2make'

    make verify
    Check-Status 'make verify'

    Write-Output 'verify-v2: ok'
}
finally {
    Pop-Location
}
