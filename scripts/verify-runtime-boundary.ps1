$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$AsmPath = Join-Path $Root 'src/deadwire_windows.s'
$RoadmapPath = Join-Path $Root 'docs/v2-native-runtime-parity-roadmap.md'
$ContractPath = Join-Path $Root 'docs/v2-runtime-boundary-contract.md'

foreach ($Path in @($AsmPath, $RoadmapPath, $ContractPath)) {
    if (-not (Test-Path $Path)) {
        throw "missing file: $Path"
    }
}

$Asm = Get-Content -Raw -Encoding UTF8 $AsmPath
$Roadmap = Get-Content -Raw -Encoding UTF8 $RoadmapPath
$Contract = Get-Content -Raw -Encoding UTF8 $ContractPath

$AsmNeedles = @(
    'mainCRTStartup:',
    '.accept_loop:',
    'handle_client:',
    'send_response:',
    'send_all:',
    'detect_content_type:',
    'write_stdout:',
    'die:',
    'call accept',
    'call handle_client',
    'call recv',
    'call send_response',
    'call send_all'
)

foreach ($Needle in $AsmNeedles) {
    if (-not $Asm.Contains($Needle)) {
        throw "runtime boundary check failed: $Needle"
    }
}

$RoadmapNeedles = @(
    'V2.0: Runtime Boundary',
    'custom native thread abstraction',
    'custom synchronization primitive layer',
    'worker-pool accept dispatch',
    'benchmark proves scaling or the claim is not made'
)

foreach ($Needle in $RoadmapNeedles) {
    if (-not $Roadmap.Contains($Needle)) {
        throw "roadmap check failed: $Needle"
    }
}

$ContractNeedles = @(
    'NO BEHAVIOR CHANGE IN V2.0',
    'NO THREADS YET',
    'runtime_handle_client(connection*)',
    'runtime_send_all(connection*, buffer, length)'
)

foreach ($Needle in $ContractNeedles) {
    if (-not $Contract.Contains($Needle)) {
        throw "contract check failed: $Needle"
    }
}

Write-Output 'verify-runtime-boundary: ok'
