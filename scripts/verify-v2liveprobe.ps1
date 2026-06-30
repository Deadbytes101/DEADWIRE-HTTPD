$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$LivePath = Join-Path $RepoRoot 'src/runtime/runtime_live_windows.s'
$LiveClosePath = Join-Path $RepoRoot 'src/runtime/runtime_live_close_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$LiveObjectPath = Join-Path $BuildDir 'runtime_v2liveprobe_live.o'
$LiveCloseObjectPath = Join-Path $BuildDir 'runtime_v2liveprobe_close.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2liveprobe.c'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2liveprobe.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2liveprobe.exe'

foreach ($Path in @($LivePath, $LiveClosePath)) {
    if (-not (Test-Path $Path)) {
        throw "missing V2 live probe input: $Path"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $LiveObjectPath $LivePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live probe open assembly failed with exit code $LASTEXITCODE"
}

& as --64 -o $LiveCloseObjectPath $LiveClosePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live probe close assembly failed with exit code $LASTEXITCODE"
}

@'
#include <stdint.h>
#include <winsock2.h>
#include <ws2tcpip.h>

extern int dw_runtime_live_open(uint64_t *ctx);
extern int dw_runtime_live_close(uint64_t *ctx);

int main(void) {
    struct sockaddr_in addr;
    uint64_t live_ctx[5];

    addr.sin_family = AF_INET;
    addr.sin_port = 0;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    live_ctx[0] = 0;
    live_ctx[1] = (uint64_t)&addr;
    live_ctx[2] = sizeof(addr);
    live_ctx[3] = 1;
    live_ctx[4] = 99;

    if (dw_runtime_live_open(live_ctx) != 0) return 1;
    if (live_ctx[0] == 0) return 2;
    if (live_ctx[4] != 0) return 3;

    if (dw_runtime_live_close(live_ctx) != 0) return 4;
    if (live_ctx[0] != 0) return 5;
    if (live_ctx[4] != 0) return 6;

    return 0;
}
'@ | Set-Content -Encoding ASCII $HarnessPath

& gcc -c -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live probe harness compile failed with exit code $LASTEXITCODE"
}

& gcc -o $HarnessExePath $HarnessObjectPath $LiveObjectPath $LiveCloseObjectPath -lws2_32
if ($LASTEXITCODE -ne 0) {
    throw "V2 live probe harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live probe harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2liveprobe: ok'
