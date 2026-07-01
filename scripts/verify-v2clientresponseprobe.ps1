$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$RT=Join-Path $R 'src/runtime/runtime_route_windows.s'
if(!(Test-Path $RT)){throw "missing $RT"}
$RO=Join-Path $B 'v2clientresponse_route.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as route'}
$C=Join-Path $B 'verify_runtime_v2clientresponseprobe.c'
$CO=Join-Path $B 'verify_runtime_v2clientresponseprobe.o'
$EX=Join-Path $B 'verify_runtime_v2clientresponseprobe.exe'
@'
#include <stdint.h>

extern int dw_runtime_client_select_response(uint64_t *client, int route, uint64_t health, uint64_t root, uint64_t css, uint64_t missing);

#define ROUTE_HEALTH 1
#define ROUTE_ROOT 2
#define ROUTE_CSS 3
#define ROUTE_MISSING 4

static int check_client(uint64_t *client, int route, uint64_t expected) {
    const uint64_t health = 0x1111;
    const uint64_t root = 0x2222;
    const uint64_t css = 0x3333;
    const uint64_t missing = 0x4444;
    client[3] = 99;
    if (dw_runtime_client_select_response(client, route, health, root, css, missing)) return 1;
    return client[3] == expected;
}

int main(void) {
    uint64_t client[4] = {0, 0, 0, 99};

    if (!check_client(client, ROUTE_HEALTH, 0x1111)) return 1;
    if (!check_client(client, ROUTE_ROOT, 0x2222)) return 2;
    if (!check_client(client, ROUTE_CSS, 0x3333)) return 3;
    if (!check_client(client, ROUTE_MISSING, 0x4444)) return 4;
    if (!check_client(client, 99, 0x4444)) return 5;
    if (!check_client(client, 0, 0x4444)) return 6;

    if (dw_runtime_client_select_response(0, ROUTE_HEALTH, 0x1111, 0x2222, 0x3333, 0x4444) != 1) return 7;
    client[3] = 99;
    if (dw_runtime_client_select_response(client, ROUTE_HEALTH, 0, 0x2222, 0x3333, 0x4444) != 1) return 8;
    if (client[3] != 99) return 9;

    return 0;
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $CO $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $CO $RO; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2clientresponseprobe: ok'
