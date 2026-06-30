$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_tick_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2tickproof.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2tickproof.c'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2tickproof.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2tickproof.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing V2 tick source: $SourcePath"
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 tick assembly failed with exit code $LASTEXITCODE"
}

@'
#include <stdint.h>

extern int dw_runtime_tick_once(uint64_t *ctx);

static uint64_t live_ctx = 0;
static uint64_t client_ctx = 0;
static uint64_t input_queue = 0;
static uint64_t worker_ctx = 0;
static uint64_t output_queue = 0;
static uint64_t output_client = 0;

static uint64_t bridge_count = 0;
static uint64_t work_count = 0;
static uint64_t output_count = 0;
static uint64_t bridge_live_seen = 0;
static uint64_t bridge_client_seen = 0;
static uint64_t bridge_queue_seen = 0;
static uint64_t work_seen = 0;
static uint64_t output_seen = 0;

int dw_runtime_live_bridge_once(uint64_t *live, uint64_t *client, uint64_t *queue) {
    bridge_count++;
    bridge_live_seen = (uint64_t)live;
    bridge_client_seen = (uint64_t)client;
    bridge_queue_seen = (uint64_t)queue;
    return 0;
}

int dw_runtime_work_step(uint64_t *worker) {
    work_count++;
    work_seen = (uint64_t)worker;
    return 0;
}

uint64_t dw_runtime_output_drain(uint64_t *queue) {
    output_count++;
    output_seen = (uint64_t)queue;
    return (uint64_t)&output_client;
}

int main(void) {
    uint64_t tick_ctx[7] = {
        (uint64_t)&live_ctx,
        (uint64_t)&client_ctx,
        (uint64_t)&input_queue,
        (uint64_t)&worker_ctx,
        (uint64_t)&output_queue,
        99,
        99
    };

    if (dw_runtime_tick_once(0) != 1) return 1;
    if (dw_runtime_tick_once(tick_ctx) != 0) return 2;
    if (tick_ctx[5] != (uint64_t)&output_client) return 3;
    if (tick_ctx[6] != 0) return 4;
    if (bridge_count != 1 || work_count != 1 || output_count != 1) return 5;
    if (bridge_live_seen != (uint64_t)&live_ctx) return 6;
    if (bridge_client_seen != (uint64_t)&client_ctx) return 7;
    if (bridge_queue_seen != (uint64_t)&input_queue) return 8;
    if (work_seen != (uint64_t)&worker_ctx) return 9;
    if (output_seen != (uint64_t)&output_queue) return 10;
    return 0;
}
'@ | Set-Content -Encoding ASCII $HarnessPath

& gcc -c -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 tick proof harness compile failed with exit code $LASTEXITCODE"
}

& gcc -o $HarnessExePath $HarnessObjectPath $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 tick proof harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 tick proof harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2tickproof: ok'
