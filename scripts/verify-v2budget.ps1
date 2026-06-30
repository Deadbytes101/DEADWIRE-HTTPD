$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Program=Join-Path $R 'build/deadwire_v2_runtime.exe'
if(!(Test-Path $Program)){throw "missing $Program"}
$D=(& objdump -d $Program) -join "`n"
if($LASTEXITCODE){throw "v2 budget disasm $LASTEXITCODE"}
function Block([string]$Name){
    $P="(?ms)<$([regex]::Escape($Name))>:\s*\r?\n(?<body>.*?)(?=^[0-9a-fA-F]+\s+<|\z)"
    $M=[regex]::Match($D,$P)
    if(!$M.Success){throw "missing budget block $Name"}
    return $M.Groups['body'].Value
}
function InstructionCount([string]$Name){
    $B=Block $Name
    return ([regex]::Matches($B,'(?m)^\s*[0-9a-fA-F]+:\s+')).Count
}
$Budget=@{
    'dw_runtime_accept_enqueue'=3
    'dw_runtime_output_drain'=3
    'dw_runtime_worker_take'=48
    'dw_runtime_worker_complete'=54
    'dw_runtime_work_step'=16
}
foreach($Name in $Budget.Keys){
    $Count=InstructionCount $Name
    $Max=$Budget[$Name]
    if($Count -gt $Max){throw "$Name instruction budget $Count > $Max"}
}
Write-Output 'verify-v2budget: ok'
