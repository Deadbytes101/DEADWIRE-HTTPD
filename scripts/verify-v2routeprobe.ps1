$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$RT=Join-Path $R 'src/runtime/runtime_route_windows.s'
if(!(Test-Path $RT)){throw "missing $RT"}
$RO=Join-Path $B 'v2route_runtime.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as route'}
$C=Join-Path $B 'verify_runtime_v2routeprobe.c'
$CO=Join-Path $B 'verify_runtime_v2routeprobe.o'
$EX=Join-Path $B 'verify_runtime_v2routeprobe.exe'
@'
#include <stdint.h>

extern int dw_runtime_select_route(const char *request, int request_length);

#define ROUTE_HEALTH 1
#define ROUTE_ROOT 2
#define ROUTE_CSS 3
#define ROUTE_MISSING 4

static int check_route(const char *request, int request_length, int expected_route) {
    return dw_runtime_select_route(request, request_length) == expected_route;
}

int main(void) {
    const char health_get[] = "GET /health HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
    const char health_head[] = "HEAD /health HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
    const char root_get[] = "GET / HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
    const char css_get[] = "GET /style.css HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
    const char missing_get[] = "GET /missing HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
    const char health_prefix[] = "GET /healthz HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
    const char css_prefix[] = "GET /style.cssx HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
    const char health_query[] = "GET /health?x=1 HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
    const char malformed[] = "GET/health HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";

    if (!check_route(health_get, (int)(sizeof(health_get) - 1), ROUTE_HEALTH)) return 1;
    if (!check_route(health_head, (int)(sizeof(health_head) - 1), ROUTE_HEALTH)) return 2;
    if (!check_route(root_get, (int)(sizeof(root_get) - 1), ROUTE_ROOT)) return 3;
    if (!check_route(css_get, (int)(sizeof(css_get) - 1), ROUTE_CSS)) return 4;
    if (!check_route(missing_get, (int)(sizeof(missing_get) - 1), ROUTE_MISSING)) return 5;
    if (!check_route(health_prefix, (int)(sizeof(health_prefix) - 1), ROUTE_MISSING)) return 6;
    if (!check_route(css_prefix, (int)(sizeof(css_prefix) - 1), ROUTE_MISSING)) return 7;
    if (!check_route(health_query, (int)(sizeof(health_query) - 1), ROUTE_MISSING)) return 8;
    if (!check_route(malformed, (int)(sizeof(malformed) - 1), ROUTE_MISSING)) return 9;
    if (dw_runtime_select_route(0, 0) != ROUTE_MISSING) return 10;

    return 0;
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $CO $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $CO $RO; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2routeprobe: ok'
