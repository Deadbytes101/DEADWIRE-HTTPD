$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$LivePath = Join-Path $RepoRoot 'src/runtime/runtime_live_windows.s'
$AcceptPath = Join-Path $RepoRoot 'src/runtime/runtime_accept_windows.s'
$LiveClosePath = Join-Path $RepoRoot 'src/runtime/runtime_live_close_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$LiveObjectPath = Join-Path $BuildDir 'runtime_v2acceptprobe_live.o'
$AcceptObjectPath = Join-Path $BuildDir 'runtime_v2acceptprobe_accept.o'
$LiveCloseObjectPath = Join-Path $BuildDir 'runtime_v2acceptprobe_close.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2acceptprobe.c'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2acceptprobe.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2acceptprobe.exe'

foreach ($Path in @($LivePath, $AcceptPath, $LiveClosePath)) {
    if (-not (Test-Path $Path)) {
        throw "missing V2 accept probe input: $Path"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $LiveObjectPath $LivePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 accept probe live assembly failed with exit code $LASTEXITCODE"
}

& as --64 -o $AcceptObjectPath $AcceptPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 accept probe accept assembly failed with exit code $LASTEXITCODE"
}

& as --64 -o $LiveCloseObjectPath $LiveClosePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 accept probe close assembly failed with exit code $LASTEXITCODE"
}

@'
#include <stdint.h>
#include <winsock2.h>
#include <ws2tcpip.h>

extern int dw_runtime_live_open(uint64_t *ctx);
extern int dw_runtime_live_accept_once(uint64_t *live_ctx, uint64_t *client_ctx);
extern int dw_runtime_live_close(uint64_t *ctx);

int main(void) {
    struct sockaddr_in addr;
    struct sockaddr_in bound_addr;
    int bound_len = sizeof(bound_addr);
    uint64_t live_ctx[5];
    uint64_t client_ctx[4];
    SOCKET outbound_socket = INVALID_SOCKET;

    addr.sin_family = AF_INET;
    addr.sin_port = 0;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    live_ctx[0] = 0;
    live_ctx[1] = (uint64_t)&addr;
    live_ctx[2] = sizeof(addr);
    live_ctx[3] = 1;
    live_ctx[4] = 99;

    client_ctx[0] = 99;
    client_ctx[1] = 0;
    client_ctx[2] = 0;
    client_ctx[3] = 0;

    if (dw_runtime_live_open(live_ctx) != 0) return 1;
    if (live_ctx[0] == 0) return 2;
    if (live_ctx[4] != 0) return 3;

    if (getsockname((SOCKET)live_ctx[0], (struct sockaddr *)&bound_addr, &bound_len) != 0) return 4;
    if (bound_addr.sin_port == 0) return 5;

    outbound_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (outbound_socket == INVALID_SOCKET) return 6;
    if (connect(outbound_socket, (struct sockaddr *)&bound_addr, sizeof(bound_addr)) != 0) return 7;

    if (dw_runtime_live_accept_once(live_ctx, client_ctx) != 0) return 8;
    if (live_ctx[4] != 0) return 9;
    if (client_ctx[0] == 0) return 10;

    closesocket((SOCKET)client_ctx[0]);
    closesocket(outbound_socket);

    if (dw_runtime_live_close(live_ctx) != 0) return 11;
    if (live_ctx[0] != 0) return 12;
    if (live_ctx[4] != 0) return 13;

    return 0;
}
'@ | Set-Content -Encoding ASCII $HarnessPath

& gcc -c -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 accept probe harness compile failed with exit code $LASTEXITCODE"
}

& gcc -o $HarnessExePath $HarnessObjectPath $LiveObjectPath $AcceptObjectPath $LiveCloseObjectPath -lws2_32
if ($LASTEXITCODE -ne 0) {
    throw "V2 accept probe harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 accept probe harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2acceptprobe: ok'
