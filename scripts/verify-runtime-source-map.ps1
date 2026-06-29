$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_windows_map.o'

if (-not (Test-Path $SourcePath)) {
    throw "missing runtime source map: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredSymbols = @(
    'dw_runtime_main:',
    'dw_runtime_accept_loop:',
    'dw_runtime_handle_client:',
    'dw_runtime_send_response:',
    'dw_runtime_send_all:',
    'dw_runtime_write_output:'
)

foreach ($Symbol in $RequiredSymbols) {
    if (-not $Source.Contains($Symbol)) {
        throw "missing runtime anchor symbol: $Symbol"
    }
}

$RequiredSendAllNeedles = @(
    '# dw_runtime_send_all(socket rcx, buffer rdx, length r8) maps to send_all.',
    '.dw_runtime_send_loop:',
    'call send',
    'cdqe',
    'add qword ptr [rbp - 16], rax',
    'sub qword ptr [rbp - 24], rax'
)

foreach ($Needle in $RequiredSendAllNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing runtime send_all logic: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "runtime source map assembly failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $ObjectPath)) {
    throw "runtime source map object was not produced: $ObjectPath"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "runtime source map symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
$RequiredObjectSymbols = @(
    'dw_runtime_main',
    'dw_runtime_accept_loop',
    'dw_runtime_handle_client',
    'dw_runtime_send_response',
    'dw_runtime_send_all',
    'dw_runtime_write_output',
    'send'
)

foreach ($Symbol in $RequiredObjectSymbols) {
    if (-not $SymbolText.Contains($Symbol)) {
        throw "missing runtime object symbol: $Symbol"
    }
}

Write-Output 'verify-runtime-source-map: ok'
