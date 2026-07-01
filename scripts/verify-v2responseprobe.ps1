$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$RT=Join-Path $R 'src/runtime/runtime_route_windows.s'
if(!(Test-Path $RT)){throw "missing $RT"}
$RO=Join-Path $B 'v2response_route.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as route'}
$C=Join-Path $B 'verify_runtime_v2responseprobe.c'
$CO=Join-Path $B 'verify_runtime_v2responseprobe.o'
$EX=Join-Path $B 'verify_runtime_v2responseprobe.exe'
@'
#include <stdint.h>

extern uint64_t dw_runtime_response_for_route(int route, uint64_t health, uint64_t root, uint64_t css, uint64_t missing);

#define ROUTE_HEALTH 1
#define ROUTE_ROOT 2
#define ROUTE_CSS 3
#define ROUTE_MISSING 4

int main(void) {
    const uint64_t health = 0x1111;
    const uint64_t root = 0x2222;
    const uint64_t css = 0x3333;
    const uint64_t missing = 0x4444;

    if (dw_runtime_response_for_route(ROUTE_HEALTH, health, root, css, missing) != health) return 1;
    if (dw_runtime_response_for_route(ROUTE_ROOT, health, root, css, missing) != root) return 2;
    if (dw_runtime_response_for_route(ROUTE_CSS, health, root, css, missing) != css) return 3;
    if (dw_runtime_response_for_route(ROUTE_MISSING, health, root, css, missing) != missing) return 4;
    if (dw_runtime_response_for_route(99, health, root, css, missing) != missing) return 5;
    if (dw_runtime_response_for_route(0, health, root, css, missing) != missing) return 6;

    return 0;
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $CO $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $CO $RO; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2responseprobe: ok'
