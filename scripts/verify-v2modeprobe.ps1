$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$ShapeProbe=Join-Path $R 'scripts/verify-v2lane-shape.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ShapeProbe
if($LASTEXITCODE){throw "lane shape $LASTEXITCODE"}
$HotShapeProbe=Join-Path $R 'scripts/verify-v2hotshape.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HotShapeProbe
if($LASTEXITCODE){throw "hot shape $LASTEXITCODE"}
$HotObjectProbe=Join-Path $R 'scripts/verify-v2hotobject.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HotObjectProbe
if($LASTEXITCODE){throw "hot object $LASTEXITCODE"}
$AcceptorProbe=Join-Path $R 'scripts/verify-v2acceptorprobe.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AcceptorProbe
if($LASTEXITCODE){throw "acceptor probe $LASTEXITCODE"}
$HttpProbe=Join-Path $R 'scripts/verify-v2httpengineprobe.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HttpProbe
if($LASTEXITCODE){throw "http engine probe $LASTEXITCODE"}
$RouteProbe=Join-Path $R 'scripts/verify-v2routeprobe.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RouteProbe
if($LASTEXITCODE){throw "route probe $LASTEXITCODE"}
$ResponseProbe=Join-Path $R 'scripts/verify-v2responseprobe.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ResponseProbe
if($LASTEXITCODE){throw "response probe $LASTEXITCODE"}
$ClientResponseProbe=Join-Path $R 'scripts/verify-v2clientresponseprobe.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ClientResponseProbe
if($LASTEXITCODE){throw "client response probe $LASTEXITCODE"}
$RouteFlowProbe=Join-Path $R 'scripts/verify-v2routeflowprobe.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RouteFlowProbe
if($LASTEXITCODE){throw "route flow probe $LASTEXITCODE"}
$BootShapeProbe=Join-Path $R 'scripts/verify-v2bootshape.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BootShapeProbe
if($LASTEXITCODE){throw "boot shape $LASTEXITCODE"}
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$Gen=Join-Path $R 'scripts/gen-v2-runtime-hot.ps1'
$RT=Join-Path $B 'deadwire_v2_runtime_hot.s'
$ROUTE=Join-Path $R 'src/runtime/runtime_route_windows.s'
$LV=Join-Path $R 'src/runtime/runtime_live_windows.s'
$AC=Join-Path $R 'src/runtime/runtime_accept_windows.s'
$BR=Join-Path $R 'src/runtime/runtime_bridge_windows.s'
$TK=Join-Path $R 'src/runtime/runtime_tick_windows.s'
$BD=Join-Path $R 'src/runtime/runtime_bound_windows.s'
$MO=Join-Path $R 'src/runtime/runtime_mode_windows.s'
$HE=Join-Path $R 'src/runtime/runtime_http_engine_entry_windows.s'
$CL=Join-Path $R 'src/runtime/runtime_live_close_windows.s'
foreach($P in @($Gen,$ROUTE,$LV,$AC,$BR,$TK,$BD,$MO,$HE,$CL)){if(!(Test-Path $P)){throw "missing $P"}}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Gen
if($LASTEXITCODE){throw "gen hot $LASTEXITCODE"}
$RO=Join-Path $B 'v2mp_runtime.o'; $RTO=Join-Path $B 'v2mp_route.o'; $LO=Join-Path $B 'v2mp_live.o'; $AO=Join-Path $B 'v2mp_accept.o'; $BO=Join-Path $B 'v2mp_bridge.o'; $TO=Join-Path $B 'v2mp_tick.o'; $BDO=Join-Path $B 'v2mp_bound.o'; $MOO=Join-Path $B 'v2mp_mode.o'; $HO=Join-Path $B 'v2mp_http.o'; $CLO=Join-Path $B 'v2mp_close.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as runtime'}
& as --64 -o $RTO $ROUTE; if($LASTEXITCODE){throw 'as route'}
& as --64 -o $LO $LV; if($LASTEXITCODE){throw 'as live'}
& as --64 -o $AO $AC; if($LASTEXITCODE){throw 'as accept'}
& as --64 -o $BO $BR; if($LASTEXITCODE){throw 'as bridge'}
& as --64 -o $TO $TK; if($LASTEXITCODE){throw 'as tick'}
& as --64 -o $BDO $BD; if($LASTEXITCODE){throw 'as bound'}
& as --64 -o $MOO $MO; if($LASTEXITCODE){throw 'as mode'}
& as --64 -o $HO $HE; if($LASTEXITCODE){throw 'as http'}
& as --64 -o $CLO $CL; if($LASTEXITCODE){throw 'as close'}
$C=Join-Path $B 'verify_runtime_v2modeprobe.c'
$CO=Join-Path $B 'verify_runtime_v2modeprobe.o'
$EX=Join-Path $B 'verify_runtime_v2modeprobe.exe'
@'
#include <stdint.h>
#include <string.h>
#include <winsock2.h>
#include <ws2tcpip.h>
extern int dw_runtime_live_open(uint64_t*);
extern int dw_runtime_live_close(uint64_t*);
extern int dw_runtime_worker_init(uint64_t*,uint64_t,uint64_t*,uint64_t*);
extern int dw_runtime_mode_bound(uint64_t*);
int main(void){
 struct sockaddr_in a,b; int bl=sizeof(b);
 char reqbuf[512]={0},outbuf[1024]={0};
 const char req[]="GET / HTTP/1.1\r\nHost: localhost\r\n\r\n";
 const char status[]="HTTP/1.1 200 OK\r\n";
 const char type[]="text/plain";
 const char body[]="V2 MODE OK";
 uint64_t resp[6]={(uint64_t)status,sizeof(status)-1,(uint64_t)type,sizeof(type)-1,(uint64_t)body,sizeof(body)-1};
 uint64_t ii[4]={0},oi[4]={0},iq[4]={0,0,4,(uint64_t)ii},oq[4]={0,0,4,(uint64_t)oi};
 uint64_t w[5]={0},live[5]={0,0,0,0,99},client[8]={99,(uint64_t)reqbuf,sizeof(reqbuf),0,(uint64_t)resp,(uint64_t)resp,(uint64_t)resp,(uint64_t)resp},tc[7]={0},bc[4]={0},mc[2]={0};
 SOCKET out=INVALID_SOCKET;
 a.sin_family=AF_INET; a.sin_port=0; a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 live[1]=(uint64_t)&a; live[2]=sizeof(a); live[3]=1;
 tc[0]=(uint64_t)live; tc[1]=(uint64_t)client; tc[2]=(uint64_t)iq; tc[3]=(uint64_t)w; tc[4]=(uint64_t)oq; tc[5]=99; tc[6]=99;
 bc[0]=(uint64_t)tc; bc[1]=1; bc[2]=99; bc[3]=99; mc[0]=(uint64_t)bc; mc[1]=99;
 if(dw_runtime_worker_init(w,7,iq,oq))return 1;
 if(dw_runtime_live_open(live))return 2;
 if(getsockname((SOCKET)live[0],(struct sockaddr*)&b,&bl))return 3;
 out=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP); if(out==INVALID_SOCKET)return 4;
 if(connect(out,(struct sockaddr*)&b,sizeof(b)))return 5;
 if(client[3])return 6;
 if(send(out,req,(int)(sizeof(req)-1),0)!=(int)(sizeof(req)-1))return 7;
 if(dw_runtime_mode_bound(mc))return 8;
 if(mc[1]!=0||bc[2]!=1||bc[3]!=0)return 9;
 if(client[3]!=(uint64_t)resp)return 10;
 if(tc[5]!=(uint64_t)client||tc[6]!=0)return 11;
 if(w[4]!=1||iq[0]!=1||iq[1]!=1||oq[0]!=1||oq[1]!=1)return 12;
 int n=recv(out,outbuf,sizeof(outbuf)-1,0); if(n<=0)return 13; outbuf[n]=0;
 if(!strstr(outbuf,"HTTP/1.1 200 OK"))return 14;
 if(!strstr(outbuf,"V2 MODE OK"))return 15;
 closesocket((SOCKET)client[0]); closesocket(out);
 if(dw_runtime_live_close(live))return 16;
 return live[0]||live[4];
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $CO $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $CO $RO $RTO $LO $AO $BO $TO $BDO $MOO $HO $CLO -lws2_32 -lkernel32; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2modeprobe: ok'
$HandleProbe=Join-Path $R 'scripts/verify-v2handleprobe.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HandleProbe
if($LASTEXITCODE){throw "handle probe $LASTEXITCODE"}
$RunProbe=Join-Path $R 'scripts/verify-v2run.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RunProbe
if($LASTEXITCODE){throw "run probe $LASTEXITCODE"}
