$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_tick_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2step.o'
if (-not (Test-Path $SourcePath)) { throw "missing source: $SourcePath" }
$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
foreach ($Needle in @('dw_runtime_tick_once:', 'DW_TICK_LAST_RESULT')) {
    if (-not $Source.Contains($Needle)) { throw "missing rule: $Needle" }
}
if (-not (Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir | Out-Null }
& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) { throw "assembly failed with exit code $LASTEXITCODE" }
Write-Output 'verify-v2step: ok'
