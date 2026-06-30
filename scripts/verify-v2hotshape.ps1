$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Gen=Join-Path $R 'scripts/gen-v2-runtime-hot.ps1'
$Hot=Join-Path $R 'build/deadwire_v2_runtime_hot.s'
if(!(Test-Path $Gen)){throw "missing $Gen"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Gen
if($LASTEXITCODE){throw "hot source gen $LASTEXITCODE"}
if(!(Test-Path $Hot)){throw "missing $Hot"}
$S=Get-Content -Raw -Encoding UTF8 $Hot
function Block([string]$Name){
    $M=[regex]::Match($S,"(?ms)^$([regex]::Escape($Name)):\s*\r?\n(?<body>.*?)(?=^[A-Za-z_][A-Za-z0-9_]*:|\z)")
    if(!$M.Success){throw "missing hot block $Name"}
    return $M.Groups['body'].Value
}
function NoFrame([string]$Name){
    $B=Block $Name
    if($B -match 'push\s+rbp'){throw "$Name has frame push"}
    if($B -match 'leave'){throw "$Name has frame leave"}
}
foreach($Name in @('dw_runtime_accept_enqueue','dw_runtime_output_drain','dw_runtime_worker_take','dw_runtime_worker_complete','dw_runtime_work_step')){NoFrame $Name}
if((Block 'dw_runtime_accept_enqueue') -notmatch 'jmp\s+dw_runtime_queue_push'){throw 'accept enqueue is not tail-call push'}
if((Block 'dw_runtime_output_drain') -notmatch 'jmp\s+dw_runtime_queue_pop'){throw 'output drain is not tail-call pop'}
if((Block 'dw_runtime_worker_take') -match 'call\s+dw_runtime_queue_pop'){throw 'worker take still calls queue pop'}
if((Block 'dw_runtime_worker_complete') -match 'call\s+dw_runtime_queue_push'){throw 'worker complete still calls queue push'}
if((Block 'dw_runtime_work_step') -match '\[rbp'){throw 'work step still uses stack frame'}
Write-Output 'verify-v2hotshape: ok'
