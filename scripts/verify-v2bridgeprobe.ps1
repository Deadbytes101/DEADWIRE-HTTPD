$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$LivePath = Join-Path $RepoRoot 'src/runtime/runtime_live_windows.s'
$AcceptPath = Join-Path $RepoRoot 'src/runtime/runtime_accept_windows.s'
$BridgePath = Join-Path $RepoRoot 'src/runtime/runtime_bridge_windows.s'
$LiveClosePath = Join-Path $RepoRoot 'src/runtime/runtime_live_close_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$RuntimeObjectPath = Join-Path $BuildDir 'runtime_v2bridgeprobe_runtime.o'
$LiveObjectPath = Join-Path $BuildDir 'runtime_v2bridgeprobe_live.o'
$AcceptObjectPath = Join-Path $BuildDir 'runtime_v2bridgeprobe_accept.o'
$BridgeObjectPath = Join-Path $BuildDir 'runtime_v2bridgeprobe_bridge.o'
$LiveCloseObjectPath = Join-Path $BuildDir 'runtime_v2bridgeprobe_close.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2bridgeprobe.c'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2bridgeprobe.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2bridgeprobe.exe'

foreach ($Path in @($RuntimePath, $LivePath, $AcceptPath, $BridgePath, $LiveClosePath)) {
    if (-not (Test-Path $Path)) { throw "missing V2 bridge probe input: $Path" }
}
if (-not (Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir | Out-Null }

& as --64 -o $RuntimeObjectPath $RuntimePath
if ($LASTEXITCODE -ne 0) { throw "V2 bridge probe runtime assembly failed with exit code $LASTEXITCODE" }
& as --64 -o $LiveObjectPath $LivePath
if ($LASTEXITCODE -ne 0) { throw "V2 bridge probe live assembly failed with exit code $LASTEXITCODE" }
& as --64 -o $AcceptObjectPath $AcceptPath
if ($LASTEXITCODE -ne 0) { throw "V2 bridge probe accept assembly failed with exit code $LASTEXITCODE" }
& as --64 -o $BridgeObjectPath $BridgePath
if ($LASTEXITCODE -ne 0) { throw "V2 bridge probe bridge assembly failed with exit code $LASTEXITCODE" }
& as --64 -o $LiveCloseObjectPath $LiveClosePath
if ($LASTEXITCODE -ne 0) { throw "V2 bridge probe close assembly failed with exit code $LASTEXITCODE" }

@'
#include <stdint.h>
#include <winsock2.h>
#include <ws2tcpip.h>

extern int dw_runtime_live_open(uint64_t *ctx);
extern int dw_runtime_live_bridge_once(uint64_t *live_ctx, uint64_t *client_ctx, uint64_t *queue);
extern int dw_runtime_live_close(uint64_t *ctx);

int main(void) {
    struct sockaddr_in addr;
    struct sockaddr_in bound_addr;
    int bound_len = sizeof(bound_addr);
    uint64_t items[4] = {0,0,0,0};
    uint64_t queue[4] = {0,0,4,(uint64_t)items};
    uint64_t live_ctx[5] = {0,0,0,0,99};
    uint64_t client_ctx[4] = {99,0,0,0};
    SOCKET outbound_socket = INVALID_SOCKET;

    addr.sin_family = AF_INET;
    addr.sin_port = 0;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    live_ctx[1] = (uint64_t)&addr;
    live_ctx[2] = sizeof(addr);
    live_ctx[3] = 1;

    if (dw_runtime_live_open(live_ctx) != 0) return 1;
    if (getsockname((SOCKET)live_ctx[0], (struct sockaddr *)&bound_addr, &bound_len) != 0) return 2;
    outbound_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (outbound_socket == INVALID_SOCKET) return 3;
    if (connect(outbound_socket, (struct sockaddr *)&bound_addr, sizeof(bound_addr)) != 0) return 4;

    if (dw_runtime_live_bridge_once(live_ctx, client_ctx, queue) != 0) return 5;
    if (live_ctx[4] != 0) return 6;
    if (client_ctx[0] == 0) return 7;
    if (queue[0] != 0 || queue[1] != 1) return 8;
    if (items[0] != (uint64_t)client_ctx) return 9;

    closesocket((SOCKET)client_ctx[0]);
    closesocket(outbound_socket);
    if (dw_runtime_live_close(live_ctx) != 0) return 10;
    if (live_ctx[0] != 0 || live_ctx[4] != 0) return 11;
    return 0;
}
'@ | Set-Content -Encoding ASCII $HarnessPath

& gcc -c -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) { throw "V2 bridge probe harness compile failed with exit code $LASTEXITCODE" }
& gcc -o $HarnessExePath $HarnessObjectPath $RuntimeObjectPath $LiveObjectPath $AcceptObjectPath $BridgeObjectPath $LiveCloseObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) { throw "V2 bridge probe harness link failed with exit code $LASTEXITCODE" }
& $HarnessExePath
if ($LASTEXITCODE -ne 0) { throw "V2 bridge probe harness failed with exit code $LASTEXITCODE" }

Write-Output 'verify-v2bridgeprobe: ok'
