$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$AsmPath = Join-Path $Root 'src/deadwire_windows.s'
$RoadmapPath = Join-Path $Root 'docs/v2-native-runtime-parity-roadmap.md'
$ContractPath = Join-Path $Root 'docs/v2-runtime-boundary-contract.md'
$SourceMapPath = Join-Path $Root 'docs/v2-source-boundary-map.md'
$RuntimeReadmePath = Join-Path $Root 'src/runtime/README.md'
$WindowsBackendReadmePath = Join-Path $Root 'src/platform/windows/README.md'
$RuntimeAnchorPath = Join-Path $Root 'src/runtime/boundary_anchors.txt'
$AssemblyAnchorPath = Join-Path $Root 'src/runtime/boundary_anchors.asm.txt'

foreach ($Path in @($AsmPath, $RoadmapPath, $ContractPath, $SourceMapPath, $RuntimeReadmePath, $WindowsBackendReadmePath, $RuntimeAnchorPath, $AssemblyAnchorPath)) {
    if (-not (Test-Path $Path)) {
        throw "missing file: $Path"
    }
}

$Asm = Get-Content -Raw -Encoding UTF8 $AsmPath
$Roadmap = Get-Content -Raw -Encoding UTF8 $RoadmapPath
$Contract = Get-Content -Raw -Encoding UTF8 $ContractPath
$SourceMap = Get-Content -Raw -Encoding UTF8 $SourceMapPath
$RuntimeReadme = Get-Content -Raw -Encoding UTF8 $RuntimeReadmePath
$WindowsBackendReadme = Get-Content -Raw -Encoding UTF8 $WindowsBackendReadmePath
$RuntimeAnchor = Get-Content -Raw -Encoding UTF8 $RuntimeAnchorPath
$AssemblyAnchor = Get-Content -Raw -Encoding UTF8 $AssemblyAnchorPath

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

$SourceMapNeedles = @(
    'src/runtime/',
    'src/platform/windows/',
    'NO C SERVER GLUE',
    'NO THREADS BEFORE BOUNDARY'
)

foreach ($Needle in $SourceMapNeedles) {
    if (-not $SourceMap.Contains($Needle)) {
        throw "source boundary map check failed: $Needle"
    }
}

foreach ($Needle in @('Runtime owns', 'NO BEHAVIOR CHANGE WHILE SPLITTING THE BOUNDARY')) {
    if (-not $RuntimeReadme.Contains($Needle)) {
        throw "runtime readme check failed: $Needle"
    }
}

foreach ($Needle in @('Backend owns', 'DO NOT MIX POLICY WITH PLATFORM PLUMBING')) {
    if (-not $WindowsBackendReadme.Contains($Needle)) {
        throw "windows backend readme check failed: $Needle"
    }
}

foreach ($Needle in @('mainCRTStartup is the current entry boundary', 'send_response is the current response builder boundary', 'write_stdout is the current platform output boundary')) {
    if (-not $RuntimeAnchor.Contains($Needle)) {
        throw "runtime anchor check failed: $Needle"
    }
}

foreach ($Needle in @('mainCRTStartup entry boundary', 'send_response response boundary', 'write_stdout output boundary')) {
    if (-not $AssemblyAnchor.Contains($Needle)) {
        throw "assembly anchor check failed: $Needle"
    }
}

Write-Output 'verify-runtime-boundary: ok'
