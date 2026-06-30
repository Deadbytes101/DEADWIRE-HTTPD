$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_handle_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2handle.o'

if (-not (Test-Path $SourcePath)) {
    throw "missing V2 handle source: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'WaitForSingleObject',
    'CloseHandle',
    'dw_runtime_wait_handle:',
    'dw_runtime_close_handle:'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 handle source rule: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 handle assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 handle symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
foreach ($Symbol in @('dw_runtime_wait_handle', 'dw_runtime_close_handle')) {
    if (-not $SymbolText.Contains($Symbol)) {
        throw "missing runtime object symbol: $Symbol"
    }
}

Write-Output 'verify-v2handle: ok'
