$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_bound_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2bound.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2bound.c'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2bound.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2bound.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing V2 bound source: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'dw_runtime_bound_n:',
    'dw_runtime_tick_once',
    'DW_BOUND_TICK_CONTEXT_PTR',
    'DW_BOUND_COUNT',
    'DW_BOUND_COMPLETED',
    'DW_BOUND_LAST_RESULT'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 bound rule: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 bound assembly failed with exit code $LASTEXITCODE"
}

@'
#include <stdint.h>

extern int dw_runtime_bound_n(uint64_t *ctx);

static uint64_t tick_ctx = 0;
static uint64_t tick_count = 0;
static uint64_t tick_seen = 0;
static uint64_t fail_at = 0;

int dw_runtime_tick_once(uint64_t *ctx) {
    tick_count++;
    tick_seen = (uint64_t)ctx;
    if (fail_at != 0 && tick_count == fail_at) return 1;
    return 0;
}

int main(void) {
    uint64_t zero_ctx[4] = { (uint64_t)&tick_ctx, 0, 99, 99 };
    uint64_t ok_ctx[4] = { (uint64_t)&tick_ctx, 3, 99, 99 };
    uint64_t fail_ctx[4] = { (uint64_t)&tick_ctx, 3, 99, 99 };

    if (dw_runtime_bound_n(0) != 1) return 1;

    tick_count = 0;
    tick_seen = 0;
    fail_at = 0;
    if (dw_runtime_bound_n(zero_ctx) != 0) return 2;
    if (zero_ctx[2] != 0) return 3;
    if (zero_ctx[3] != 0) return 4;
    if (tick_count != 0) return 5;

    tick_count = 0;
    tick_seen = 0;
    fail_at = 0;
    if (dw_runtime_bound_n(ok_ctx) != 0) return 6;
    if (ok_ctx[2] != 3) return 7;
    if (ok_ctx[3] != 0) return 8;
    if (tick_count != 3) return 9;
    if (tick_seen != (uint64_t)&tick_ctx) return 10;

    tick_count = 0;
    tick_seen = 0;
    fail_at = 2;
    if (dw_runtime_bound_n(fail_ctx) != 1) return 11;
    if (fail_ctx[2] != 1) return 12;
    if (fail_ctx[3] != 1) return 13;
    if (tick_count != 2) return 14;
    if (tick_seen != (uint64_t)&tick_ctx) return 15;

    return 0;
}
'@ | Set-Content -Encoding ASCII $HarnessPath

& gcc -c -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 bound harness compile failed with exit code $LASTEXITCODE"
}

& gcc -o $HarnessExePath $HarnessObjectPath $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 bound harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 bound harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2bound: ok'
