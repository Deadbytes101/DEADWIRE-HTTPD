$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$RT=Join-Path $R 'src/runtime/runtime_windows.s'
$ROUTE=Join-Path $R 'src/runtime/runtime_route_windows.s'
$LV=Join-Path $R 'src/runtime/runtime_live_windows.s'
$AC=Join-Path $R 'src/runtime/runtime_accept_windows.s'
$CL=Join-Path $R 'src/runtime/runtime_live_close_windows.s'
foreach($P in @($RT,$ROUTE,$LV,$AC,$CL)){if(!(Test-Path $P)){throw "missing $P"}}
$RO=Join-Path $B 'v2hp_runtime.o'; $RTO=Join-Path $B 'v2hp_route.o'; $LO=Join-Path $B 'v2hp_live.o'; $AO=Join-Path $B 'v2hp_accept.o'; $CO=Join-Path $B 'v2hp_close.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as runtime'}
& as --64 -o $RTO $ROUTE; if($LASTEXITCODE){throw 'as route'}
& as --64 -o $LO $LV; if($LASTEXITCODE){throw 'as live'}
& as --64 -o $AO $AC; if($LASTEXITCODE){throw 'as accept'}
& as --64 -o $CO $CL; if($LASTEXITCODE){throw 'as close'}
$C=Join-Path $B 'verify_runtime_v2handleprobe.c'
$OBJ=Join-Path $B 'verify_runtime_v2handleprobe.o'
$EX=Join-Path $B 'verify_runtime_v2handleprobe.exe'
@'
#include <stdint.h>
#include <string.h>
#include <winsock2.h>
#include <ws2tcpip.h>
extern int dw_runtime_live_open(uint64_t*);
extern int dw_runtime_live_accept_once(uint64_t*,uint64_t*);
extern int dw_runtime_live_close(uint64_t*);
extern int dw_runtime_select_client_response(uint64_t*,const char*,int,uint64_t,uint64_t,uint64_t,uint64_t);
extern int dw_runtime_handle_client(uint64_t*);
int main(void){
 struct sockaddr_in a,b; int bl=sizeof(b);
 char reqbuf[512]={0}, outbuf[1024]={0};
 const char req[]="GET / HTTP/1.1\r\nHost: localhost\r\n\r\n";
 const char status[]="HTTP/1.1 200 OK\r\n";
 const char type[]="text/plain";
 const char body[]="V2 OK";
 uint64_t resp[6]={(uint64_t)status,sizeof(status)-1,(uint64_t)type,sizeof(type)-1,(uint64_t)body,sizeof(body)-1};
 uint64_t live[5]={0,0,0,0,99},client[4]={99,0,0,0};
 SOCKET out=INVALID_SOCKET;
 a.sin_family=AF_INET; a.sin_port=0; a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 live[1]=(uint64_t)&a; live[2]=sizeof(a); live[3]=1;
 if(dw_runtime_live_open(live))return 1;
 if(getsockname((SOCKET)live[0],(struct sockaddr*)&b,&bl))return 2;
 out=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP); if(out==INVALID_SOCKET)return 3;
 if(connect(out,(struct sockaddr*)&b,sizeof(b)))return 4;
 if(dw_runtime_live_accept_once(live,client))return 5;
 client[1]=(uint64_t)reqbuf; client[2]=sizeof(reqbuf);
 if(!dw_runtime_select_client_response(client,req,(int)(sizeof(req)-1),(uint64_t)resp,(uint64_t)resp,(uint64_t)resp,(uint64_t)resp))return 6;
 if(!client[3])return 7;
 if(send(out,req,(int)(sizeof(req)-1),0)!=(int)(sizeof(req)-1))return 8;
 if(dw_runtime_handle_client(client))return 9;
 int n=recv(out,outbuf,sizeof(outbuf)-1,0); if(n<=0)return 10; outbuf[n]=0;
 if(!strstr(outbuf,"HTTP/1.1 200 OK"))return 11;
 if(!strstr(outbuf,"V2 OK"))return 12;
 closesocket((SOCKET)client[0]); closesocket(out);
 if(dw_runtime_live_close(live))return 13;
 return live[0]||live[4];
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $OBJ $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $OBJ $RO $RTO $LO $AO $CO -lws2_32 -lkernel32; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2handleprobe: ok'
