$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
if(!(Test-Path $B)){New-Item -ItemType Directory -Path $B|Out-Null}
$RT=Join-Path $R 'src/runtime/runtime_windows.s'
if(!(Test-Path $RT)){throw "missing $RT"}
$RO=Join-Path $B 'v2accept_runtime.o'
& as --64 -o $RO $RT; if($LASTEXITCODE){throw 'as runtime'}
$C=Join-Path $B 'verify_runtime_v2acceptorprobe.c'
$CO=Join-Path $B 'verify_runtime_v2acceptorprobe.o'
$EX=Join-Path $B 'verify_runtime_v2acceptorprobe.exe'
@'
#include <stdint.h>
extern int dw_runtime_accept_enqueue(uint64_t*,uint64_t*);
extern int dw_runtime_accept_entry(uint64_t*);
int main(void){
 uint64_t items[4]={0};
 uint64_t q[4]={0,0,4,(uint64_t)items};
 uint64_t client_a[4]={111,0,0,0};
 uint64_t client_b[4]={222,0,0,0};
 uint64_t entry[5]={(uint64_t)q,0,0,(uint64_t)client_b,99};
 uint64_t bad_entry[5]={0,0,0,0,99};
 if(dw_runtime_accept_enqueue(q,client_a))return 1;
 if(q[0]!=0||q[1]!=1||items[0]!=(uint64_t)client_a)return 2;
 if(dw_runtime_accept_entry(entry))return 3;
 if(entry[4]!=0||q[0]!=0||q[1]!=2||items[1]!=(uint64_t)client_b)return 4;
 if(dw_runtime_accept_entry(0)!=1)return 5;
 if(dw_runtime_accept_entry(bad_entry)!=1)return 6;
 if(bad_entry[4]!=1)return 7;
 return 0;
}
'@|Set-Content -Encoding ASCII $C
& gcc -c -o $CO $C; if($LASTEXITCODE){throw 'cc'}
& gcc -o $EX $CO $RO -lws2_32 -lkernel32; if($LASTEXITCODE){throw 'link'}
& $EX; if($LASTEXITCODE){throw "run $LASTEXITCODE"}
Write-Output 'verify-v2acceptorprobe: ok'
