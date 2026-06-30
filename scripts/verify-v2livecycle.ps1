$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_live_cycle_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2livecycle.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2livecycle.c'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2livecycle.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2livecycle.exe'
if (-not (Test-Path $SourcePath)) { throw "missing source: $SourcePath" }
$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
foreach ($Needle in @('dw_runtime_live_cycle_once:', 'dw_runtime_live_open', 'dw_runtime_live_close')) {
    if (-not $Source.Contains($Needle)) { throw "missing rule: $Needle" }
}
if (-not (Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir | Out-Null }
& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) { throw "assembly failed with exit code $LASTEXITCODE" }
@'
#include <stdint.h>
extern int dw_runtime_live_cycle_once(uint64_t *ctx);
static uint64_t oc = 0, cc = 0, os = 0, cs = 0, mode = 0;
int dw_runtime_live_open(uint64_t *ctx) { oc++; os = (uint64_t)ctx; ctx[4] = mode == 1 ? 1 : 0; return mode == 1 ? 1 : 0; }
int dw_runtime_live_close(uint64_t *ctx) { cc++; cs = (uint64_t)ctx; ctx[4] = mode == 2 ? 1 : 0; return mode == 2 ? 1 : 0; }
int main(void) {
    uint64_t ctx[5] = {0,0,0,0,99};
    if (dw_runtime_live_cycle_once(0) != 1) return 1;
    oc = cc = os = cs = mode = 0; ctx[4] = 99;
    if (dw_runtime_live_cycle_once(ctx) != 0) return 2;
    if (ctx[4] != 0 || oc != 1 || cc != 1) return 3;
    if (os != (uint64_t)ctx || cs != (uint64_t)ctx) return 4;
    oc = cc = os = cs = 0; mode = 1; ctx[4] = 99;
    if (dw_runtime_live_cycle_once(ctx) != 1) return 5;
    if (ctx[4] != 1 || oc != 1 || cc != 0) return 6;
    oc = cc = os = cs = 0; mode = 2; ctx[4] = 99;
    if (dw_runtime_live_cycle_once(ctx) != 1) return 7;
    if (ctx[4] != 1 || oc != 1 || cc != 1) return 8;
    return 0;
}
'@ | Set-Content -Encoding ASCII $HarnessPath
& gcc -c -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) { throw "harness compile failed with exit code $LASTEXITCODE" }
& gcc -o $HarnessExePath $HarnessObjectPath $ObjectPath
if ($LASTEXITCODE -ne 0) { throw "harness link failed with exit code $LASTEXITCODE" }
& $HarnessExePath
if ($LASTEXITCODE -ne 0) { throw "harness failed with exit code $LASTEXITCODE" }
Write-Output 'verify-v2livecycle: ok'
