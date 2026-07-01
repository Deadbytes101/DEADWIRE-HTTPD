$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$Gen=Join-Path $R 'scripts/gen-v2-runtime-hot.ps1'
$Hot=Join-Path $B 'deadwire_v2_runtime_hot.s'
$Route=Join-Path $R 'src/runtime/runtime_route_windows.s'
$Live=Join-Path $R 'src/runtime/runtime_live_windows.s'
$Accept=Join-Path $R 'src/runtime/runtime_accept_windows.s'
$Close=Join-Path $R 'src/runtime/runtime_live_close_windows.s'
foreach($P in @($Gen,$Route,$Live,$Accept,$Close)){if(!(Test-Path $P)){throw "missing $P"}}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Gen
if($LASTEXITCODE){throw "gen hot $LASTEXITCODE"}
$HotObj=Join-Path $B 'v2routeflow_hot.o'
$RouteObj=Join-Path $B 'v2routeflow_route.o'
$LiveObj=Join-Path $B 'v2routeflow_live.o'
$AcceptObj=Join-Path $B 'v2routeflow_accept.o'
$CloseObj=Join-Path $B 'v2routeflow_close.o'
& as --64 -o $HotObj $Hot; if($LASTEXITCODE){throw 'as hot'}
& as --64 -o $RouteObj $Route; if($LASTEXITCODE){throw 'as route'}
& as --64 -o $LiveObj $Live; if($LASTEXITCODE){throw 'as live'}
& as --64 -o $AcceptObj $Accept; if($LASTEXITCODE){throw 'as accept'}
& as --64 -o $CloseObj $Close; if($LASTEXITCODE){throw 'as close'}
$C=Join-Path $B 'verify_runtime_v2routeflowprobe.c'
$CO=Join-Path $B 'verify_runtime_v2routeflowprobe.o'
$EX=Join-Path $B 'verify_runtime_v2routeflowprobe.exe'
@'
#include <stdint.h>
#include <string.h>
#include <winsock2.h>
#include <ws2tcpip.h>

extern int dw_runtime_live_open(uint64_t *live_context);
extern int dw_runtime_live_accept_once(uint64_t *live_context, uint64_t *client_context);
extern int dw_runtime_live_close(uint64_t *live_context);
extern int dw_runtime_handle_client(uint64_t *client_context);

static int has_text(const char *buffer, int length, const char *needle) {
    int needle_length = (int)strlen(needle);
    for (int i = 0; i <= length - needle_length; ++i) {
        if (!memcmp(buffer + i, needle, (size_t)needle_length)) return 1;
    }
    return 0;
}

static int run_one(uint64_t *live, const struct sockaddr_in *bound, const char *request, const char *expected_status, const char *expected_body) {
    const char health_status[] = "HTTP/1.1 200 OK\r\n";
    const char root_status[] = "HTTP/1.1 200 OK\r\n";
    const char css_status[] = "HTTP/1.1 200 OK\r\n";
    const char missing_status[] = "HTTP/1.1 404 Not Found\r\n";
    const char text_type[] = "text/plain";
    const char html_type[] = "text/html";
    const char css_type[] = "text/css";
    const char health_body[] = "V2 HEALTH";
    const char root_body[] = "<h1>V2 ROOT</h1>";
    const char css_body[] = "body{color:white}";
    const char missing_body[] = "V2 MISSING";
    uint64_t health[6] = {(uint64_t)health_status, sizeof(health_status)-1, (uint64_t)text_type, sizeof(text_type)-1, (uint64_t)health_body, sizeof(health_body)-1};
    uint64_t root[6] = {(uint64_t)root_status, sizeof(root_status)-1, (uint64_t)html_type, sizeof(html_type)-1, (uint64_t)root_body, sizeof(root_body)-1};
    uint64_t css[6] = {(uint64_t)css_status, sizeof(css_status)-1, (uint64_t)css_type, sizeof(css_type)-1, (uint64_t)css_body, sizeof(css_body)-1};
    uint64_t missing[6] = {(uint64_t)missing_status, sizeof(missing_status)-1, (uint64_t)text_type, sizeof(text_type)-1, (uint64_t)missing_body, sizeof(missing_body)-1};
    char request_buffer[512] = {0};
    char response_buffer[2048] = {0};
    uint64_t client[8] = {99, (uint64_t)request_buffer, sizeof(request_buffer), 0, (uint64_t)health, (uint64_t)root, (uint64_t)css, (uint64_t)missing};
    SOCKET peer = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (peer == INVALID_SOCKET) return 1;
    if (connect(peer, (const struct sockaddr *)bound, sizeof(*bound))) return 2;
    if (dw_runtime_live_accept_once(live, client)) return 3;
    if (client[3]) return 4;
    int request_length = (int)strlen(request);
    if (send(peer, request, request_length, 0) != request_length) return 5;
    if (dw_runtime_handle_client(client)) return 6;
    if (!client[3]) return 7;
    int received = recv(peer, response_buffer, sizeof(response_buffer)-1, 0);
    if (received <= 0) return 8;
    response_buffer[received] = 0;
    if (!has_text(response_buffer, received, expected_status)) return 9;
    if (!has_text(response_buffer, received, expected_body)) return 10;
    closesocket((SOCKET)client[0]);
    closesocket(peer);
    return 0;
}

int main(void) {
    struct sockaddr_in addr, bound;
    int bound_len = sizeof(bound);
    uint64_t live[5] = {0, 0, 0, 0, 99};
    addr.sin_family = AF_INET;
    addr.sin_port = 0;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    live[1] = (uint64_t)&addr;
    live[2] = sizeof(addr);
    live[3] = 4;
    if (dw_runtime_live_open(live)) return 1;
    if (getsockname((SOCKET)live[0], (struct sockaddr *)&bound, &bound_len)) return 2;
    if (run_one(live, &bound, "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n", "HTTP/1.1 200 OK", "V2 HEALTH")) return 3;
    if (run_one(live, &bound, "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n", "HTTP/1.1 200 OK", "V2 ROOT")) return 4;
    if (run_one(live, &bound, "GET /style.css HTTP/1.1\r\nHost: localhost\r\n\r\n", "HTTP/1.1 200 OK", "body{color:white}")) return 5;
    if (run_one(live, &bound, "GET /missing HTTP/1.1\r\nHost: localhost\r\n\r\n", "HTTP/1.1 404 Not Found", "V2 MISSING")) return 6;
    if (dw_runtime_live_close(live)) return 7;
    return live[0] || live[4];
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $CO $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $CO $HotObj $RouteObj $LiveObj $AcceptObj $CloseObj -lws2_32 -lkernel32; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2routeflowprobe: ok'
