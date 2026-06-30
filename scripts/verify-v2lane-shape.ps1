$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$SP=Join-Path $R 'src/runtime/runtime_spawn_set_windows.s'
$JN=Join-Path $R 'src/runtime/runtime_join_windows.s'
$BT=Join-Path $R 'src/runtime/runtime_boot_windows.s'
foreach($P in @($SP,$JN,$BT)){if(!(Test-Path $P)){throw "missing $P"}}
$S=Get-Content -Raw -Encoding UTF8 $SP
$J=Get-Content -Raw -Encoding UTF8 $JN
$B=Get-Content -Raw -Encoding UTF8 $BT
$Starts=[regex]::Matches($S,'call\s+dw_runtime_spawn_entry').Count
if($Starts -ne 2){throw "v2 lane shape: start count $Starts"}
if(!$S.Contains('dw_runtime_accept_entry')){throw 'v2 lane shape: missing accept entry'}
if(!$S.Contains('dw_runtime_work_entry')){throw 'v2 lane shape: missing http entry'}
if($S.Contains('dw_runtime_output_entry')){throw 'v2 lane shape: unexpected output entry'}
$Waits=[regex]::Matches($J,'call\s+dw_runtime_wait_handle').Count
if($Waits -ne 2){throw "v2 lane shape: wait count $Waits"}
$Closes=[regex]::Matches($J,'call\s+dw_runtime_close_handle').Count
if($Closes -ne 2){throw "v2 lane shape: close count $Closes"}
if($B.Contains('.quad output_entry_ctx')){throw 'v2 lane shape: boot still provides output context'}
if($B.Contains('.quad output_tid')){throw 'v2 lane shape: boot still provides output tid'}
Write-Output 'verify-v2lane-shape: ok'
