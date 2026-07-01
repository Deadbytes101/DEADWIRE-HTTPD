$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$B=Join-Path $R 'build'
$Gen=Join-Path $R 'scripts/gen-v2-runtime-hot.ps1'
$Hot=Join-Path $B 'deadwire_v2_runtime_hot.s'
$Obj=Join-Path $B 'deadwire_v2_runtime_hot_check.o'
if(!(Test-Path $Gen)){throw "missing $Gen"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Gen
if($LASTEXITCODE){throw "hot source gen $LASTEXITCODE"}
if(!(Test-Path $Hot)){throw "missing $Hot"}
& as --64 -o $Obj $Hot
if($LASTEXITCODE){throw "hot object as $LASTEXITCODE"}
$D=(& objdump -d $Obj) -join "`n"
if($LASTEXITCODE){throw "hot object disasm $LASTEXITCODE"}
function ObjBlock([string]$Name){
    $P="(?ms)<$([regex]::Escape($Name))>:\s*\r?\n(?<body>.*?)(?=^[0-9a-fA-F]+\s+<|\z)"
    $M=[regex]::Match($D,$P)
    if(!$M.Success){throw "missing object block $Name"}
    return $M.Groups['body'].Value
}
foreach($Name in @('dw_runtime_accept_enqueue','dw_runtime_output_drain','dw_runtime_worker_take','dw_runtime_worker_complete','dw_runtime_work_step')){
    $Body=ObjBlock $Name
    if($Body -match '\bpush\b.*%rbp'){throw "$Name object has frame push"}
    if($Body -match '\bleave\b'){throw "$Name object has frame leave"}
}
foreach($Name in @('dw_runtime_worker_take','dw_runtime_worker_complete')){
    $Body=ObjBlock $Name
    if($Body -match '\bcall\b'){throw "$Name object still has call"}
}
$Handle=ObjBlock 'dw_runtime_handle_client'
if($Handle -notmatch '\bcall\b'){throw 'handle client object has no select-client call'}
$Reloc=(& objdump -r $Obj) -join "`n"
if($LASTEXITCODE){throw "hot object reloc $LASTEXITCODE"}
if($Reloc -notmatch 'dw_runtime_select_client_response'){throw 'hot object missing select-client relocation'}
if($Reloc -match 'dw_runtime_select_route'){throw 'hot object still has split route selector relocation'}
Write-Output 'verify-v2hotobject: ok'
