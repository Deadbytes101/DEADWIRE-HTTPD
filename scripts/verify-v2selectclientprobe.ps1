$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$RT=Join-Path $R 'src/runtime/runtime_route_windows.s'
if(!(Test-Path $RT)){throw "missing $RT"}
$RO=Join-Path $B 'v2selectclient_route.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as route'}
$C=Join-Path $B 'verify_runtime_v2selectclientprobe.c'
$CO=Join-Path $B 'verify_runtime_v2selectclientprobe.o'
$EX=Join-Path $B 'verify_runtime_v2selectclientprobe.exe'
@'
#include <stdint.h>
#include <string.h>

extern int dw_runtime_select_client_response(uint64_t *client, const char *request, int request_length, uint64_t health, uint64_t root, uint64_t css, uint64_t missing);

#define ROUTE_HEALTH 1
#define ROUTE_ROOT 2
#define ROUTE_CSS 3
#define ROUTE_MISSING 4

static int run_one(const char *request, int expected_route, uint64_t expected_response) {
    uint64_t client[4] = {0, 0, 0, 99};
    const uint64_t health = 0x1111;
    const uint64_t root = 0x2222;
    const uint64_t css = 0x3333;
    const uint64_t missing = 0x4444;
    int route = dw_runtime_select_client_response(client, request, (int)strlen(request), health, root, css, missing);
    if (route != expected_route) return 0;
    return client[3] == expected_response;
}

int main(void) {
    if (!run_one("GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n", ROUTE_HEALTH, 0x1111)) return 1;
    if (!run_one("HEAD /health HTTP/1.1\r\nHost: localhost\r\n\r\n", ROUTE_HEALTH, 0x1111)) return 2;
    if (!run_one("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n", ROUTE_ROOT, 0x2222)) return 3;
    if (!run_one("GET /style.css HTTP/1.1\r\nHost: localhost\r\n\r\n", ROUTE_CSS, 0x3333)) return 4;
    if (!run_one("GET /missing HTTP/1.1\r\nHost: localhost\r\n\r\n", ROUTE_MISSING, 0x4444)) return 5;
    if (!run_one("GET /healthz HTTP/1.1\r\nHost: localhost\r\n\r\n", ROUTE_MISSING, 0x4444)) return 6;

    {
        uint64_t client[4] = {0, 0, 0, 99};
        const char request[] = "GET /health HTTP/1.1\r\n\r\n";
        if (dw_runtime_select_client_response(0, request, (int)strlen(request), 0x1111, 0x2222, 0x3333, 0x4444) != 0) return 7;
        if (dw_runtime_select_client_response(client, 0, (int)strlen(request), 0x1111, 0x2222, 0x3333, 0x4444) != 0) return 8;
        if (dw_runtime_select_client_response(client, request, 0, 0x1111, 0x2222, 0x3333, 0x4444) != 0) return 9;
        if (client[3] != 99) return 10;
    }

    return 0;
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $CO $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $CO $RO; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2selectclientprobe: ok'
