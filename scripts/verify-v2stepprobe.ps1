$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$RT=Join-Path $R 'src/runtime/runtime_windows.s'
$LV=Join-Path $R 'src/runtime/runtime_live_windows.s'
$AC=Join-Path $R 'src/runtime/runtime_accept_windows.s'
$BR=Join-Path $R 'src/runtime/runtime_bridge_windows.s'
$CL=Join-Path $R 'src/runtime/runtime_live_close_windows.s'
foreach($P in @($RT,$LV,$AC,$BR,$CL)){if(!(Test-Path $P)){throw "missing $P"}}
$RO=Join-Path $B 'v2sp_runtime.o'; $LO=Join-Path $B 'v2sp_live.o'; $AO=Join-Path $B 'v2sp_accept.o'; $BO=Join-Path $B 'v2sp_bridge.o'; $CO=Join-Path $B 'v2sp_close.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as runtime'}
& as --64 -o $LO $LV; if($LASTEXITCODE){throw 'as live'}
& as --64 -o $AO $AC; if($LASTEXITCODE){throw 'as accept'}
& as --64 -o $BO $BR; if($LASTEXITCODE){throw 'as bridge'}
& as --64 -o $CO $CL; if($LASTEXITCODE){throw 'as close'}
$C=Join-Path $B 'verify_runtime_v2stepprobe.c'
$COBJ=Join-Path $B 'verify_runtime_v2stepprobe.o'
$EXE=Join-Path $B 'verify_runtime_v2stepprobe.exe'
@'
#include <stdint.h>
#include <winsock2.h>
#include <ws2tcpip.h>
extern int dw_runtime_live_open(uint64_t*);
extern int dw_runtime_live_bridge_once(uint64_t*,uint64_t*,uint64_t*);
extern int dw_runtime_live_close(uint64_t*);
extern int dw_runtime_worker_init(uint64_t*,uint64_t,uint64_t*,uint64_t*);
extern int dw_runtime_work_step(uint64_t*);
extern uint64_t dw_runtime_output_drain(uint64_t*);
int main(void){
 struct sockaddr_in a,b; int bl=sizeof(b);
 uint64_t ii[4]={0},oi[4]={0},iq[4]={0,0,4,(uint64_t)ii},oq[4]={0,0,4,(uint64_t)oi};
 uint64_t w[5]={0},live[5]={0,0,0,0,99},client[4]={99,0,0,0};
 SOCKET out=INVALID_SOCKET;
 a.sin_family=AF_INET; a.sin_port=0; a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 live[1]=(uint64_t)&a; live[2]=sizeof(a); live[3]=1;
 if(dw_runtime_worker_init(w,7,iq,oq))return 1;
 if(dw_runtime_live_open(live))return 2;
 if(getsockname((SOCKET)live[0],(struct sockaddr*)&b,&bl))return 3;
 out=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP); if(out==INVALID_SOCKET)return 4;
 if(connect(out,(struct sockaddr*)&b,sizeof(b)))return 5;
 if(dw_runtime_live_bridge_once(live,client,iq))return 6;
 if(iq[1]!=1||ii[0]!=(uint64_t)client)return 7;
 if(dw_runtime_work_step(w))return 8;
 if(w[3]!=0||w[4]!=1||iq[0]!=1||oq[1]!=1||oi[0]!=(uint64_t)client)return 9;
 if(dw_runtime_output_drain(oq)!=(uint64_t)client)return 10;
 closesocket((SOCKET)client[0]); closesocket(out);
 if(dw_runtime_live_close(live))return 11;
 return live[0]||live[4];
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $COBJ $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EXE $COBJ $RO $LO $AO $BO $CO -lws2_32 -lkernel32; if($LASTEXITCODE){throw 'link'}
& $EXE; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2stepprobe: ok'
$CycleProbe=Join-Path $R 'scripts/verify-v2cycleprobe.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $CycleProbe
if($LASTEXITCODE){throw "cycle probe $LASTEXITCODE"}
