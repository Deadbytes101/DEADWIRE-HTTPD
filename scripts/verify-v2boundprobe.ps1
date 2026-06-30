$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$RT=Join-Path $R 'src/runtime/runtime_windows.s'
$LV=Join-Path $R 'src/runtime/runtime_live_windows.s'
$AC=Join-Path $R 'src/runtime/runtime_accept_windows.s'
$BR=Join-Path $R 'src/runtime/runtime_bridge_windows.s'
$TK=Join-Path $R 'src/runtime/runtime_tick_windows.s'
$BD=Join-Path $R 'src/runtime/runtime_bound_windows.s'
$CL=Join-Path $R 'src/runtime/runtime_live_close_windows.s'
foreach($P in @($RT,$LV,$AC,$BR,$TK,$BD,$CL)){if(!(Test-Path $P)){throw "missing $P"}}
$RO=Join-Path $B 'v2bp_runtime.o'; $LO=Join-Path $B 'v2bp_live.o'; $AO=Join-Path $B 'v2bp_accept.o'; $BO=Join-Path $B 'v2bp_bridge.o'; $TO=Join-Path $B 'v2bp_tick.o'; $BDO=Join-Path $B 'v2bp_bound.o'; $CLO=Join-Path $B 'v2bp_close.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as runtime'}
& as --64 -o $LO $LV; if($LASTEXITCODE){throw 'as live'}
& as --64 -o $AO $AC; if($LASTEXITCODE){throw 'as accept'}
& as --64 -o $BO $BR; if($LASTEXITCODE){throw 'as bridge'}
& as --64 -o $TO $TK; if($LASTEXITCODE){throw 'as tick'}
& as --64 -o $BDO $BD; if($LASTEXITCODE){throw 'as bound'}
& as --64 -o $CLO $CL; if($LASTEXITCODE){throw 'as close'}
$C=Join-Path $B 'verify_runtime_v2boundprobe.c'
$CO=Join-Path $B 'verify_runtime_v2boundprobe.o'
$EX=Join-Path $B 'verify_runtime_v2boundprobe.exe'
@'
#include <stdint.h>
#include <winsock2.h>
#include <ws2tcpip.h>
extern int dw_runtime_live_open(uint64_t*);
extern int dw_runtime_live_close(uint64_t*);
extern int dw_runtime_worker_init(uint64_t*,uint64_t,uint64_t*,uint64_t*);
extern int dw_runtime_bound_n(uint64_t*);
int main(void){
 struct sockaddr_in a,b; int bl=sizeof(b);
 uint64_t ii[4]={0},oi[4]={0},iq[4]={0,0,4,(uint64_t)ii},oq[4]={0,0,4,(uint64_t)oi};
 uint64_t w[5]={0},live[5]={0,0,0,0,99},client[4]={99,0,0,0},tc[7]={0},bc[4]={0};
 SOCKET out=INVALID_SOCKET;
 a.sin_family=AF_INET; a.sin_port=0; a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 live[1]=(uint64_t)&a; live[2]=sizeof(a); live[3]=1;
 tc[0]=(uint64_t)live; tc[1]=(uint64_t)client; tc[2]=(uint64_t)iq; tc[3]=(uint64_t)w; tc[4]=(uint64_t)oq; tc[5]=99; tc[6]=99;
 bc[0]=(uint64_t)tc; bc[1]=1; bc[2]=99; bc[3]=99;
 if(dw_runtime_worker_init(w,7,iq,oq))return 1;
 if(dw_runtime_live_open(live))return 2;
 if(getsockname((SOCKET)live[0],(struct sockaddr*)&b,&bl))return 3;
 out=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP); if(out==INVALID_SOCKET)return 4;
 if(connect(out,(struct sockaddr*)&b,sizeof(b)))return 5;
 if(dw_runtime_bound_n(bc))return 6;
 if(bc[2]!=1||bc[3]!=0)return 7;
 if(tc[5]!=(uint64_t)client||tc[6]!=0)return 8;
 if(w[4]!=1||iq[0]!=1||iq[1]!=1||oq[0]!=1||oq[1]!=1)return 9;
 closesocket((SOCKET)client[0]); closesocket(out);
 if(dw_runtime_live_close(live))return 10;
 return live[0]||live[4];
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $CO $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $CO $RO $LO $AO $BO $TO $BDO $CLO -lws2_32 -lkernel32; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2boundprobe: ok'
