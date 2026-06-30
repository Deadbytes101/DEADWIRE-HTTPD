$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$BootPath = Join-Path $RepoRoot 'src/runtime/runtime_boot_windows.s'
$BuildScript = Join-Path $RepoRoot 'scripts/build-v2-runtime.ps1'

foreach ($Path in @($BootPath, $BuildScript)) {
    if (-not (Test-Path $Path)) {
        throw "missing V2 boot input: $Path"
    }
}

$Boot = Get-Content -Raw -Encoding UTF8 $BootPath
$BuildScriptText = Get-Content -Raw -Encoding UTF8 $BuildScript

$BootNeedles = @(
    'mainCRTStartup:',
    'dw_runtime_worker_init',
    'dw_runtime_run_lanes',
    'spawn_ctx:',
    'input_queue:',
    'output_queue:',
    'accept_entry_ctx:',
    'work_entry_ctx:',
    'output_entry_ctx:'
)

foreach ($Needle in $BootNeedles) {
    if (-not $Boot.Contains($Needle)) {
        throw "missing V2 boot rule: $Needle"
    }
}

$BuildNeedles = @(
    'src/runtime/runtime_boot_windows.s',
    'deadwire_v2_runtime_boot.o',
    '$BootObjectPath'
)

foreach ($Needle in $BuildNeedles) {
    if (-not $BuildScriptText.Contains($Needle)) {
        throw "missing V2 build boot rule: $Needle"
    }
}

Write-Output 'verify-v2boot: ok'
