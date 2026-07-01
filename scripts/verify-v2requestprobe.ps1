$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$Gen=Join-Path $R 'scripts/gen-v2-runtime-hot.ps1'
$RT=Join-Path $B 'deadwire_v2_runtime_hot.s'
$ROUTE=Join-Path $R 'src/runtime/runtime_route_windows.s'
$LV=Join-Path $R 'src/runtime/runtime_live_windows.s'
$AC=Join-Path $R 'src/runtime/runtime_accept_windows.s'
$HE=Join-Path $R 'src/runtime/runtime_http_engine_entry_windows.s'
$CL=Join-Path $R 'src/runtime/runtime_live_close_windows.s'
foreach($P in @($Gen,$ROUTE,$LV,$AC,$HE,$CL)){if(!(Test-Path $P)){throw "missing $P"}}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Gen
if($LASTEXITCODE){throw "gen hot $LASTEXITCODE"}
$RO=Join-Path $B 'v2request_runtime.o'
$RTO=Join-Path $B 'v2request_route.o'
$LO=Join-Path $B 'v2request_live.o'
$AO=Join-Path $B 'v2request_accept.o'
$HO=Join-Path $B 'v2request_http.o'
$CO=Join-Path $B 'v2request_close.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as runtime'}
& as --64 -o $RTO $ROUTE; if($LASTEXITCODE){throw 'as route'}
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
static char reqbuf[512], outbuf[4096];
static uint64_t in_items[4], out_items[4], in_q[4], out_q[4], worker[5], live[5];
static uint64_t health_resp[6], root_resp[6], css_resp[6], missing_resp[6];
static const char ok_status[]="HTTP/1.1 200 OK\r\n";
static const char missing_status[]="HTTP/1.1 404 Not Found\r\n";
static const char type[]="text/plain";
static const char health_body[]="V2 HEALTH OK";
static const char root_body[]="V2 ROOT OK";
static const char css_body[]="V2 CSS OK";
static const char missing_body[]="V2 MISSING OK";
static void set_resp(uint64_t *r,const char *s,const char *b){r[0]=(uint64_t)s;r[1]=strlen(s);r[2]=(uint64_t)type;r[3]=strlen(type);r[4]=(uint64_t)b;r[5]=strlen(b);}
static int run_case(struct sockaddr_in *addr,int index,const char *req,uint64_t expected,const char *status,const char *body){
 SOCKET out=INVALID_SOCKET;
 uint64_t client[8]={99,(uint64_t)reqbuf,sizeof(reqbuf),0,(uint64_t)health_resp,(uint64_t)root_resp,(uint64_t)css_resp,(uint64_t)missing_resp};
 uint64_t cursor=(uint64_t)((index+1)&3);
 int n;
 memset(reqbuf,0,sizeof(reqbuf));
 memset(outbuf,0,sizeof(outbuf));
 out=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP); if(out==INVALID_SOCKET)return 20+index;
 if(connect(out,(struct sockaddr*)addr,sizeof(*addr)))return 30+index;
 if(dw_runtime_live_accept_once(live,client))return 40+index;
 if(dw_runtime_queue_push(in_q,(uint64_t)client))return 50+index;
 if(client[3])return 60+index;
 if(send(out,req,(int)strlen(req),0)!=(int)strlen(req))return 70+index;
 if(dw_runtime_http_request_step(worker))return 80+index;
 if(client[3]!=expected)return 90+index;
 if(dw_runtime_output_drain(out_q)!=(uint64_t)client)return 100+index;
 n=recv(out,outbuf,sizeof(outbuf)-1,0); if(n<=0)return 110+index; outbuf[n]=0;
 if(!strstr(outbuf,status))return 120+index;
 if(!strstr(outbuf,body))return 130+index;
 if(worker[4]!=(uint64_t)(index+1)||in_q[0]!=cursor||in_q[1]!=cursor||out_q[0]!=cursor||out_q[1]!=cursor)return 140+index;
 closesocket((SOCKET)client[0]); closesocket(out);
 return 0;
}
int main(void){
 struct sockaddr_in a,b; int bl=sizeof(b), r;
 const char health_req[]="GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n";
 const char root_req[]="GET / HTTP/1.1\r\nHost: localhost\r\n\r\n";
 const char css_req[]="GET /style.css HTTP/1.1\r\nHost: localhost\r\n\r\n";
 const char missing_req[]="GET /missing HTTP/1.1\r\nHost: localhost\r\n\r\n";
 set_resp(health_resp,ok_status,health_body); set_resp(root_resp,ok_status,root_body); set_resp(css_resp,ok_status,css_body); set_resp(missing_resp,missing_status,missing_body);
 in_q[2]=4; in_q[3]=(uint64_t)in_items; out_q[2]=4; out_q[3]=(uint64_t)out_items; live[4]=99;
 a.sin_family=AF_INET; a.sin_port=0; a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 live[1]=(uint64_t)&a; live[2]=sizeof(a); live[3]=1;
 if(dw_runtime_worker_init(worker,7,in_q,out_q))return 1;
 if(dw_runtime_live_open(live))return 2;
 if(getsockname((SOCKET)live[0],(struct sockaddr*)&b,&bl))return 3;
 r=run_case(&b,0,health_req,(uint64_t)health_resp,ok_status,health_body); if(r)return r;
 r=run_case(&b,1,root_req,(uint64_t)root_resp,ok_status,root_body); if(r)return r;
 r=run_case(&b,2,css_req,(uint64_t)css_resp,ok_status,css_body); if(r)return r;
 r=run_case(&b,3,missing_req,(uint64_t)missing_resp,missing_status,missing_body); if(r)return r;
 if(worker[4]!=4||in_q[0]!=0||in_q[1]!=0||out_q[0]!=0||out_q[1]!=0)return 16;
 if(dw_runtime_live_close(live))return 17;
 return live[0]||live[4];
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $OBJ $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $OBJ $RO $RTO $LO $AO $HO $CO -lws2_32 -lkernel32; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2requestprobe: ok'
