$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$RT=Join-Path $R 'src/runtime/runtime_windows.s'
$LV=Join-Path $R 'src/runtime/runtime_live_windows.s'
$AC=Join-Path $R 'src/runtime/runtime_accept_windows.s'
$HE=Join-Path $R 'src/runtime/runtime_http_engine_entry_windows.s'
$CL=Join-Path $R 'src/runtime/runtime_live_close_windows.s'
foreach($P in @($RT,$LV,$AC,$HE,$CL)){if(!(Test-Path $P)){throw "missing $P"}}
$RO=Join-Path $B 'v2request_runtime.o'
$LO=Join-Path $B 'v2request_live.o'
$AO=Join-Path $B 'v2request_accept.o'
$HO=Join-Path $B 'v2request_http.o'
$CO=Join-Path $B 'v2request_close.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as runtime'}
& as --64 -o $LO $LV; if($LASTEXITCODE){throw 'as live'}
& as --64 -o $AO $AC; if($LASTEXITCODE){throw 'as accept'}
& as --64 -o $HO $HE; if($LASTEXITCODE){throw 'as http'}
& as --64 -o $CO $CL; if($LASTEXITCODE){throw 'as close'}
$C=Join-Path $B 'verify_runtime_v2requestprobe.c'
$OBJ=Join-Path $B 'verify_runtime_v2requestprobe.o'
$EX=Join-Path $B 'verify_runtime_v2requestprobe.exe'
@'
#include <stdint.h>
#include <string.h>
#include <winsock2.h>
#include <ws2tcpip.h>
extern int dw_runtime_live_open(uint64_t*);
extern int dw_runtime_live_accept_once(uint64_t*,uint64_t*);
extern int dw_runtime_live_close(uint64_t*);
extern int dw_runtime_worker_init(uint64_t*,uint64_t,uint64_t*,uint64_t*);
extern int dw_runtime_queue_push(uint64_t*,uint64_t);
extern int dw_runtime_http_request_step(uint64_t*);
extern uint64_t dw_runtime_output_drain(uint64_t*);
int main(void){
 struct sockaddr_in a,b; int bl=sizeof(b);
 char reqbuf[512]={0}, outbuf[1024]={0};
 const char req[]="GET / HTTP/1.1\r\nHost: localhost\r\n\r\n";
 const char status[]="HTTP/1.1 200 OK\r\n";
 const char type[]="text/plain";
 const char body[]="V2 REQUEST OK";
 uint64_t resp[6]={(uint64_t)status,sizeof(status)-1,(uint64_t)type,sizeof(type)-1,(uint64_t)body,sizeof(body)-1};
 uint64_t in_items[4]={0}, out_items[4]={0};
 uint64_t in_q[4]={0,0,4,(uint64_t)in_items};
 uint64_t out_q[4]={0,0,4,(uint64_t)out_items};
 uint64_t worker[5]={0};
 uint64_t live[5]={0,0,0,0,99}, client[4]={99,(uint64_t)reqbuf,sizeof(reqbuf),(uint64_t)resp};
 SOCKET out=INVALID_SOCKET;
 a.sin_family=AF_INET; a.sin_port=0; a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 live[1]=(uint64_t)&a; live[2]=sizeof(a); live[3]=1;
 if(dw_runtime_worker_init(worker,7,in_q,out_q))return 1;
 if(dw_runtime_live_open(live))return 2;
 if(getsockname((SOCKET)live[0],(struct sockaddr*)&b,&bl))return 3;
 out=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP); if(out==INVALID_SOCKET)return 4;
 if(connect(out,(struct sockaddr*)&b,sizeof(b)))return 5;
 if(dw_runtime_live_accept_once(live,client))return 6;
 if(dw_runtime_queue_push(in_q,(uint64_t)client))return 7;
 if(send(out,req,(int)(sizeof(req)-1),0)!=(int)(sizeof(req)-1))return 8;
 if(dw_runtime_http_request_step(worker))return 9;
 if(dw_runtime_output_drain(out_q)!=(uint64_t)client)return 10;
 int n=recv(out,outbuf,sizeof(outbuf)-1,0); if(n<=0)return 11; outbuf[n]=0;
 if(!strstr(outbuf,"HTTP/1.1 200 OK"))return 12;
 if(!strstr(outbuf,"V2 REQUEST OK"))return 13;
 if(worker[4]!=1||in_q[0]!=1||in_q[1]!=1||out_q[0]!=1||out_q[1]!=1)return 14;
 closesocket((SOCKET)client[0]); closesocket(out);
 if(dw_runtime_live_close(live))return 15;
 return live[0]||live[4];
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $OBJ $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $OBJ $RO $LO $AO $HO $CO -lws2_32 -lkernel32; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2requestprobe: ok'
