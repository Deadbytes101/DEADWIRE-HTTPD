$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_mode_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2mode.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2mode.c'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2mode.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2mode.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing V2 mode source: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'dw_runtime_mode_bound:',
    'dw_runtime_bound_n',
    'DW_MODE_BOUND_CONTEXT_PTR',
    'DW_MODE_LAST_RESULT'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 mode rule: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 mode assembly failed with exit code $LASTEXITCODE"
}

@'
#include <stdint.h>

extern int dw_runtime_mode_bound(uint64_t *ctx);

static uint64_t bound_ctx = 0;
static uint64_t bound_count = 0;
static uint64_t bound_seen = 0;
static uint64_t fail_mode = 0;

int dw_runtime_bound_n(uint64_t *ctx) {
    bound_count++;
    bound_seen = (uint64_t)ctx;
    if (fail_mode != 0) return 1;
    return 0;
}

int main(void) {
    uint64_t bad_ctx[2] = { 0, 99 };
    uint64_t mode_ctx[2] = { (uint64_t)&bound_ctx, 99 };

    if (dw_runtime_mode_bound(0) != 1) return 1;

    bound_count = 0;
    if (dw_runtime_mode_bound(bad_ctx) != 1) return 2;
    if (bad_ctx[1] != 1) return 3;
    if (bound_count != 0) return 4;

    bound_count = 0;
    bound_seen = 0;
    fail_mode = 0;
    mode_ctx[1] = 99;
    if (dw_runtime_mode_bound(mode_ctx) != 0) return 5;
    if (mode_ctx[1] != 0) return 6;
    if (bound_count != 1) return 7;
    if (bound_seen != (uint64_t)&bound_ctx) return 8;

    bound_count = 0;
    bound_seen = 0;
    fail_mode = 1;
    mode_ctx[1] = 99;
    if (dw_runtime_mode_bound(mode_ctx) != 1) return 9;
    if (mode_ctx[1] != 1) return 10;
    if (bound_count != 1) return 11;
    if (bound_seen != (uint64_t)&bound_ctx) return 12;

    return 0;
}
'@ | Set-Content -Encoding ASCII $HarnessPath

& gcc -c -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 mode harness compile failed with exit code $LASTEXITCODE"
}

& gcc -o $HarnessExePath $HarnessObjectPath $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 mode harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 mode harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2mode: ok'
