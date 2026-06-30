$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Program=Join-Path $R 'build/deadwire_v2_runtime.exe'
if(!(Test-Path $Program)){throw "missing $Program"}
$D=(& objdump -d $Program) -join "`n"
if($LASTEXITCODE){throw "v2 size disasm $LASTEXITCODE"}
function Block([string]$Name){
    $P="(?ms)<$([regex]::Escape($Name))>:\s*\r?\n(?<body>.*?)(?=^[0-9a-fA-F]+\s+<|\z)"
    $M=[regex]::Match($D,$P)
    if(!$M.Success){throw "missing size block $Name"}
    return $M.Groups['body'].Value
}
function ByteCount([string]$Name){
    $B=Block $Name
    $Total=0
    foreach($M in [regex]::Matches($B,'(?m)^\s*[0-9a-fA-F]+:\s+((?:[0-9a-fA-F]{2}\s)+)')){
        $Total += [regex]::Matches($M.Groups[1].Value,'[0-9a-fA-F]{2}').Count
    }
    return $Total
}
$Budget=[ordered]@{
    'dw_runtime_accept_enqueue'=5
    'dw_runtime_output_drain'=5
    'dw_runtime_worker_take'=72
    'dw_runtime_worker_complete'=56
    'dw_runtime_work_step'=28
}
foreach($Name in $Budget.Keys){
    $Count=ByteCount $Name
    $Max=$Budget[$Name]
    Write-Output ("v2size: {0} {1}/{2}" -f $Name,$Count,$Max)
    if($Count -gt $Max){throw "$Name byte budget $Count > $Max"}
}
Write-Output 'verify-v2size: ok'
