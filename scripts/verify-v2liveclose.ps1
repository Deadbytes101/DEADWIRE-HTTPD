$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_live_close_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2liveclose.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2liveclose.c'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2liveclose.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2liveclose.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing V2 live close source: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'dw_runtime_live_close:',
    'closesocket',
    'WSACleanup',
    'DW_LIVE_SOCKET',
    'DW_LIVE_LAST_RESULT'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 live close rule: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live close assembly failed with exit code $LASTEXITCODE"
}

@'
#include <stdint.h>

extern int dw_runtime_live_close(uint64_t *ctx);

static uint64_t close_count = 0;
static uint64_t cleanup_count = 0;
static uint64_t close_seen = 0;
static uint64_t fail_close = 0;
static uint64_t fail_cleanup = 0;

int closesocket(uint64_t socket_value) {
    close_count++;
    close_seen = socket_value;
    return fail_close ? 1 : 0;
}

int WSACleanup(void) {
    cleanup_count++;
    return fail_cleanup ? 1 : 0;
}

int main(void) {
    uint64_t empty_ctx[5] = { 0, 0, 0, 0, 99 };
    uint64_t ok_ctx[5] = { 0x11112222, 0, 0, 0, 99 };
    uint64_t close_fail_ctx[5] = { 0x33334444, 0, 0, 0, 99 };
    uint64_t cleanup_fail_ctx[5] = { 0x55556666, 0, 0, 0, 99 };

    if (dw_runtime_live_close(0) != 1) return 1;

    close_count = 0;
    cleanup_count = 0;
    close_seen = 0;
    fail_close = 0;
    fail_cleanup = 0;
    if (dw_runtime_live_close(empty_ctx) != 0) return 2;
    if (empty_ctx[0] != 0) return 3;
    if (empty_ctx[4] != 0) return 4;
    if (close_count != 0 || cleanup_count != 0) return 5;

    close_count = 0;
    cleanup_count = 0;
    close_seen = 0;
    fail_close = 0;
    fail_cleanup = 0;
    if (dw_runtime_live_close(ok_ctx) != 0) return 6;
    if (ok_ctx[0] != 0) return 7;
    if (ok_ctx[4] != 0) return 8;
    if (close_count != 1 || cleanup_count != 1) return 9;
    if (close_seen != 0x11112222) return 10;

    close_count = 0;
    cleanup_count = 0;
    close_seen = 0;
    fail_close = 1;
    fail_cleanup = 0;
    if (dw_runtime_live_close(close_fail_ctx) != 1) return 11;
    if (close_fail_ctx[0] != 0) return 12;
    if (close_fail_ctx[4] != 1) return 13;
    if (close_count != 1 || cleanup_count != 1) return 14;
    if (close_seen != 0x33334444) return 15;

    close_count = 0;
    cleanup_count = 0;
    close_seen = 0;
    fail_close = 0;
    fail_cleanup = 1;
    if (dw_runtime_live_close(cleanup_fail_ctx) != 1) return 16;
    if (cleanup_fail_ctx[0] != 0) return 17;
    if (cleanup_fail_ctx[4] != 1) return 18;
    if (close_count != 1 || cleanup_count != 1) return 19;
    if (close_seen != 0x55556666) return 20;

    return 0;
}
'@ | Set-Content -Encoding ASCII $HarnessPath

& gcc -c -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live close harness compile failed with exit code $LASTEXITCODE"
}

& gcc -o $HarnessExePath $HarnessObjectPath $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live close harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live close harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2liveclose: ok'
