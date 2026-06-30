$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Program=Join-Path $R 'build/deadwire_v2_runtime.exe'
if(!(Test-Path $Program)){throw "missing $Program"}
$D=(& objdump -d $Program) -join "`n"
if($LASTEXITCODE){throw "hot exe disasm $LASTEXITCODE"}
function ExeBlock([string]$Name){
    $P="(?ms)<$([regex]::Escape($Name))>:\s*\r?\n(?<body>.*?)(?=^[0-9a-fA-F]+\s+<|\z)"
    $M=[regex]::Match($D,$P)
    if(!$M.Success){throw "missing exe block $Name"}
    return $M.Groups['body'].Value
}
foreach($Name in @('dw_runtime_accept_enqueue','dw_runtime_output_drain','dw_runtime_worker_take','dw_runtime_worker_complete','dw_runtime_work_step')){
    $Body=ExeBlock $Name
    if($Body -match '\bpush\b.*%rbp'){throw "$Name exe has frame push"}
    if($Body -match '\bleave\b'){throw "$Name exe has frame leave"}
}
foreach($Name in @('dw_runtime_worker_take','dw_runtime_worker_complete')){
    $Body=ExeBlock $Name
    if($Body -match '\bcall\b'){throw "$Name exe still has call"}
}
Write-Output 'verify-v2hotexe: ok'
