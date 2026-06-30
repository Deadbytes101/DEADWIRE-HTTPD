$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Program=Join-Path $R 'build/deadwire_v2_runtime.exe'
if(!(Test-Path $Program)){throw "missing $Program"}
$D=(& objdump -d $Program) -join "`n"
if($LASTEXITCODE){throw "v2 branch budget disasm $LASTEXITCODE"}
function Block([string]$Name){
    $P="(?ms)<$([regex]::Escape($Name))>:\s*\r?\n(?<body>.*?)(?=^[0-9a-fA-F]+\s+<|\z)"
    $M=[regex]::Match($D,$P)
    if(!$M.Success){throw "missing branch budget block $Name"}
    return $M.Groups['body'].Value
}
function BranchCount([string]$Name){
    $B=Block $Name
    return ([regex]::Matches($B,'(?m)\bj[a-z]+\b')).Count
}
$Budget=[ordered]@{
    'dw_runtime_accept_enqueue'=1
    'dw_runtime_output_drain'=1
    'dw_runtime_worker_take'=6
    'dw_runtime_worker_complete'=7
    'dw_runtime_work_step'=2
}
foreach($Name in $Budget.Keys){
    $Count=BranchCount $Name
    $Max=$Budget[$Name]
    Write-Output ("v2branchbudget: {0} {1}/{2}" -f $Name,$Count,$Max)
    if($Count -gt $Max){throw "$Name branch budget $Count > $Max"}
}
Write-Output 'verify-v2branchbudget: ok'
