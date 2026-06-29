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

Write-Output 'verify-runtime-source-map: ok'
