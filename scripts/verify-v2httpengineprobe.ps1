$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$RT=Join-Path $R 'src/runtime/runtime_windows.s'
$HE=Join-Path $R 'src/runtime/runtime_http_engine_entry_windows.s'
foreach($P in @($RT,$HE)){if(!(Test-Path $P)){throw "missing $P"}}
$RO=Join-Path $B 'v2http_runtime.o'
$HO=Join-Path $B 'v2http_engine.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as runtime'}
& as --64 -o $HO $HE; if($LASTEXITCODE){throw 'as http engine'}
$C=Join-Path $B 'verify_runtime_v2httpengineprobe.c'
$CO=Join-Path $B 'verify_runtime_v2httpengineprobe.o'
$EX=Join-Path $B 'verify_runtime_v2httpengineprobe.exe'
@'
#include <stdint.h>
extern int dw_runtime_worker_init(uint64_t*,uint64_t,uint64_t*,uint64_t*);
extern int dw_runtime_queue_push(uint64_t*,uint64_t);
extern int dw_runtime_http_engine_step(uint64_t*);
extern int dw_runtime_http_engine_entry(uint64_t*);
int main(void){
 uint64_t in_items[4]={0}, out_items[4]={0};
 uint64_t in_q[4]={0,0,4,(uint64_t)in_items};
 uint64_t out_q[4]={0,0,4,(uint64_t)out_items};
 uint64_t worker[5]={0};
 uint64_t client_a[4]={111,0,0,0};
 uint64_t client_b[4]={222,0,0,0};
 uint64_t entry[5]={0,0,0,0,99};
 uint64_t bad_entry[5]={0,0,0,0,99};
 if(dw_runtime_worker_init(worker,7,in_q,out_q))return 1;
 if(dw_runtime_queue_push(in_q,(uint64_t)client_a))return 2;
 if(dw_runtime_http_engine_step(worker))return 3;
 if(worker[4]!=1||in_q[0]!=1||in_q[1]!=1||out_q[1]!=1)return 4;
 if(out_items[0]!=(uint64_t)client_a)return 5;
 if(dw_runtime_queue_push(in_q,(uint64_t)client_b))return 6;
 entry[1]=(uint64_t)worker;
 if(dw_runtime_http_engine_entry(entry))return 7;
 if(entry[4]!=0||worker[4]!=2||in_q[0]!=2||in_q[1]!=2||out_q[1]!=2)return 8;
 if(out_items[1]!=(uint64_t)client_b)return 9;
 if(dw_runtime_http_engine_entry(0)!=1)return 10;
 if(dw_runtime_http_engine_entry(bad_entry)!=1)return 11;
 if(bad_entry[4]!=1)return 12;
 return 0;
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $CO $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $CO $RO $HO -lws2_32 -lkernel32; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2httpengineprobe: ok'
