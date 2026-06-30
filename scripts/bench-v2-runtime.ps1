param(
    [int]$Requests = 262144,
    [int]$Capacity = 1024,
    [int]$Rounds = 5
)

$ErrorActionPreference = 'Stop'
if ($Requests -lt 1) { throw 'Requests must be >= 1' }
if ($Capacity -lt 4) { throw 'Capacity must be >= 4' }
if ($Rounds -lt 1) { throw 'Rounds must be >= 1' }

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$BuildDir = Join-Path $RepoRoot 'build'
$GenHot = Join-Path $RepoRoot 'scripts/gen-v2-runtime-hot.ps1'
$HotSource = Join-Path $BuildDir 'deadwire_v2_runtime_hot.s'
$EngineSource = Join-Path $RepoRoot 'src/runtime/runtime_http_engine_entry_windows.s'
$HotObject = Join-Path $BuildDir 'bench_v2_runtime_hot.o'
$EngineObject = Join-Path $BuildDir 'bench_v2_http_engine.o'
$HarnessSource = Join-Path $BuildDir 'bench_v2_runtime.c'
$HarnessExe = Join-Path $BuildDir 'bench_v2_runtime.exe'

if (!(Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir | Out-Null }
if (!(Test-Path $GenHot)) { throw "missing $GenHot" }
if (!(Test-Path $EngineSource)) { throw "missing $EngineSource" }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $GenHot
if ($LASTEXITCODE) { throw "gen hot failed $LASTEXITCODE" }
& as --64 -o $HotObject $HotSource
if ($LASTEXITCODE) { throw "assemble hot runtime failed $LASTEXITCODE" }
& as --64 -o $EngineObject $EngineSource
if ($LASTEXITCODE) { throw "assemble http engine failed $LASTEXITCODE" }

@'
#include <stdint.h>
#include <stdio.h>
#include <windows.h>
#ifndef REQUESTS
#define REQUESTS 262144
#endif
#ifndef CAPACITY
#define CAPACITY 1024
#endif
extern int dw_runtime_worker_init(uint64_t *worker, uint64_t id, uint64_t *input_queue, uint64_t *output_queue);
extern int dw_runtime_queue_push(uint64_t *queue, uint64_t item);
extern int dw_runtime_http_engine_step(uint64_t *worker);
extern uint64_t dw_runtime_output_drain(uint64_t *output_queue);
int main(void) {
    uint64_t in_items[CAPACITY] = {0};
    uint64_t out_items[CAPACITY] = {0};
    uint64_t input_queue[4] = {0, 0, CAPACITY, (uint64_t)in_items};
    uint64_t output_queue[4] = {0, 0, CAPACITY, (uint64_t)out_items};
    uint64_t worker[5] = {0};
    uint64_t item[4] = {1, 0, 0, 0};
    if (dw_runtime_worker_init(worker, 1, input_queue, output_queue)) return 1;
    LARGE_INTEGER frequency, start, stop;
    if (!QueryPerformanceFrequency(&frequency)) return 2;
    QueryPerformanceCounter(&start);
    for (uint64_t i = 0; i < (uint64_t)REQUESTS; ++i) {
        if (dw_runtime_queue_push(input_queue, (uint64_t)item)) return 3;
        if (dw_runtime_http_engine_step(worker)) return 4;
        if (dw_runtime_output_drain(output_queue) != (uint64_t)item) return 5;
    }
    QueryPerformanceCounter(&stop);
    if (worker[4] != (uint64_t)REQUESTS) return 6;
    double seconds = (double)(stop.QuadPart - start.QuadPart) / (double)frequency.QuadPart;
    double ns_per_op = (seconds * 1000000000.0) / (double)REQUESTS;
    double ops_per_second = (double)REQUESTS / seconds;
    printf("bench-v2-runtime: requests=%llu seconds=%.9f ns/op=%.2f ops/s=%.2f\n", (unsigned long long)REQUESTS, seconds, ns_per_op, ops_per_second);
    return 0;
}
'@ | Set-Content -Encoding ASCII $HarnessSource

$GccArgs = @(
    '-O2',
    "-DREQUESTS=$Requests",
    "-DCAPACITY=$Capacity",
    '-o',
    $HarnessExe,
    $HarnessSource,
    $HotObject,
    $EngineObject,
    '-lws2_32',
    '-lkernel32'
)
& gcc @GccArgs
if ($LASTEXITCODE) { throw "bench harness link failed $LASTEXITCODE" }

$NsPerOpValues = @()
for ($Round = 1; $Round -le $Rounds; $Round++) {
    $Output = & $HarnessExe
    if ($LASTEXITCODE) { throw "bench-v2-runtime failed $LASTEXITCODE" }
    $Output | ForEach-Object { Write-Output $_ }
    $Text = $Output -join "`n"
    $Match = [regex]::Match($Text, 'ns/op=([0-9.]+)')
    if (!$Match.Success) { throw 'bench output missing ns/op' }
    $NsPerOpValues += [double]$Match.Groups[1].Value
}

$SortedNs = $NsPerOpValues | Sort-Object
$Middle = [int]($SortedNs.Count / 2)
if (($SortedNs.Count % 2) -eq 0) {
    $MedianNs = ($SortedNs[$Middle - 1] + $SortedNs[$Middle]) / 2.0
} else {
    $MedianNs = $SortedNs[$Middle]
}

Write-Output ("bench-v2-runtime-summary: rounds={0} median-ns/op={1:N2}" -f $Rounds, $MedianNs)
