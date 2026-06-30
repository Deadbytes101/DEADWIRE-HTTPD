$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Program=Join-Path $R 'build/deadwire_v2_runtime.exe'
if(!(Test-Path $Program)){throw "missing $Program"}
$D=(& objdump -d $Program) -join "`n"
if($LASTEXITCODE){throw "v2 call budget disasm $LASTEXITCODE"}
function Block([string]$Name){
    $P="(?ms)<$([regex]::Escape($Name))>:\s*\r?\n(?<body>.*?)(?=^[0-9a-fA-F]+\s+<|\z)"
    $M=[regex]::Match($D,$P)
    if(!$M.Success){throw "missing call budget block $Name"}
    return $M.Groups['body'].Value
}
function CallCount([string]$Name){
    $B=Block $Name
    return ([regex]::Matches($B,'(?m)\bcall\b')).Count
}
$Budget=[ordered]@{
    'dw_runtime_accept_enqueue'=0
    'dw_runtime_output_drain'=0
    'dw_runtime_worker_take'=0
    'dw_runtime_worker_complete'=0
    'dw_runtime_work_step'=2
}
foreach($Name in $Budget.Keys){
    $Count=CallCount $Name
    $Max=$Budget[$Name]
    Write-Output ("v2callbudget: {0} {1}/{2}" -f $Name,$Count,$Max)
    if($Count -gt $Max){throw "$Name call budget $Count > $Max"}
}
Write-Output 'verify-v2callbudget: ok'
