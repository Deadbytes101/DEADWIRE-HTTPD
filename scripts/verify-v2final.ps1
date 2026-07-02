$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Build=Join-Path $R 'scripts/build-v2-runtime.ps1'
$BuildSourceProbe=Join-Path $R 'scripts/verify-v2buildsource.ps1'
$RequestProbe=Join-Path $R 'scripts/verify-v2requestprobe.ps1'
$LivePathProbe=Join-Path $R 'scripts/verify-v2livepath.ps1'
$AssetsProbe=Join-Path $R 'scripts/verify-v2assets.ps1'
$MakePathProbe=Join-Path $R 'scripts/verify-v2makepath.ps1'
$TargetProbe=Join-Path $R 'scripts/verify-v2target.ps1'
$PostBuildProbe=Join-Path $R 'scripts/verify-v2postbuild.ps1'
$TopologyProbe=Join-Path $R 'scripts/verify-v2topology.ps1'
$LiveBenchProbe=Join-Path $R 'scripts/verify-v2livebench.ps1'
$ExternalBenchProbe=Join-Path $R 'scripts/verify-externalbench.ps1'
$ScoreBenchProbe=Join-Path $R 'scripts/verify-scorebench.ps1'
$LinuxScoreBenchProbe=Join-Path $R 'scripts/verify-linux-scorebench.ps1'
$NihserverCompatProbe=Join-Path $R 'scripts/verify-nihserver-compat.ps1'
$NihserverPatchedProbe=Join-Path $R 'scripts/verify-nihserver-patched-section.ps1'
$BenchmarkResultsProbe=Join-Path $R 'scripts/verify-benchmark-results.ps1'
$FinalGateProbe=Join-Path $R 'scripts/verify-v2finalgate.ps1'
$HotExeProbe=Join-Path $R 'scripts/verify-v2hotexe.ps1'
$BudgetProbe=Join-Path $R 'scripts/verify-v2budget.ps1'
$SizeProbe=Join-Path $R 'scripts/verify-v2size.ps1'
$CallBudgetProbe=Join-Path $R 'scripts/verify-v2callbudget.ps1'
$BranchBudgetProbe=Join-Path $R 'scripts/verify-v2branchbudget.ps1'
$SelectClientProbe=Join-Path $R 'scripts/verify-v2selectclientprobe.ps1'
$SelectChainProbe=Join-Path $R 'scripts/verify-v2selectchain.ps1'
$Program=Join-Path $R 'build/deadwire_v2_runtime.exe'
if(!(Test-Path $Build)){throw "missing $Build"}
if(!(Test-Path $BuildSourceProbe)){throw "missing $BuildSourceProbe"}
if(!(Test-Path $RequestProbe)){throw "missing $RequestProbe"}
if(!(Test-Path $LivePathProbe)){throw "missing $LivePathProbe"}
if(!(Test-Path $AssetsProbe)){throw "missing $AssetsProbe"}
if(!(Test-Path $MakePathProbe)){throw "missing $MakePathProbe"}
if(!(Test-Path $TargetProbe)){throw "missing $TargetProbe"}
if(!(Test-Path $PostBuildProbe)){throw "missing $PostBuildProbe"}
if(!(Test-Path $TopologyProbe)){throw "missing $TopologyProbe"}
if(!(Test-Path $LiveBenchProbe)){throw "missing $LiveBenchProbe"}
if(!(Test-Path $ExternalBenchProbe)){throw "missing $ExternalBenchProbe"}
if(!(Test-Path $ScoreBenchProbe)){throw "missing $ScoreBenchProbe"}
if(!(Test-Path $LinuxScoreBenchProbe)){throw "missing $LinuxScoreBenchProbe"}
if(!(Test-Path $NihserverCompatProbe)){throw "missing $NihserverCompatProbe"}
if(!(Test-Path $NihserverPatchedProbe)){throw "missing $NihserverPatchedProbe"}
if(!(Test-Path $BenchmarkResultsProbe)){throw "missing $BenchmarkResultsProbe"}
if(!(Test-Path $FinalGateProbe)){throw "missing $FinalGateProbe"}
if(!(Test-Path $HotExeProbe)){throw "missing $HotExeProbe"}
if(!(Test-Path $BudgetProbe)){throw "missing $BudgetProbe"}
if(!(Test-Path $SizeProbe)){throw "missing $SizeProbe"}
if(!(Test-Path $CallBudgetProbe)){throw "missing $CallBudgetProbe"}
if(!(Test-Path $BranchBudgetProbe)){throw "missing $BranchBudgetProbe"}
if(!(Test-Path $SelectClientProbe)){throw "missing $SelectClientProbe"}
if(!(Test-Path $SelectChainProbe)){throw "missing $SelectChainProbe"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $FinalGateProbe
if($LASTEXITCODE){throw "v2 final gate $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MakePathProbe
if($LASTEXITCODE){throw "v2 make path $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TargetProbe
if($LASTEXITCODE){throw "v2 target $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PostBuildProbe
if($LASTEXITCODE){throw "v2 post build $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TopologyProbe
if($LASTEXITCODE){throw "v2 topology $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LiveBenchProbe
if($LASTEXITCODE){throw "v2 live bench $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ExternalBenchProbe
if($LASTEXITCODE){throw "external bench $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScoreBenchProbe
if($LASTEXITCODE){throw "score bench $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LinuxScoreBenchProbe
if($LASTEXITCODE){throw "linux score bench $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $NihserverCompatProbe
if($LASTEXITCODE){throw "nihserver compat $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $NihserverPatchedProbe
if($LASTEXITCODE){throw "nihserver patched $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BenchmarkResultsProbe
if($LASTEXITCODE){throw "benchmark results $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SelectChainProbe
if($LASTEXITCODE){throw "v2 select chain $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SelectClientProbe
if($LASTEXITCODE){throw "v2 select client $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BuildSourceProbe
if($LASTEXITCODE){throw "v2 build source $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RequestProbe
if($LASTEXITCODE){throw "v2 request coverage $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LivePathProbe
if($LASTEXITCODE){throw "v2 live path $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AssetsProbe
if($LASTEXITCODE){throw "v2 assets $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build
if($LASTEXITCODE){throw "v2 final build $LASTEXITCODE"}
if(!(Test-Path $Program)){throw "missing $Program"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HotExeProbe
if($LASTEXITCODE){throw "v2 hot exe $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BudgetProbe
if($LASTEXITCODE){throw "v2 budget $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SizeProbe
if($LASTEXITCODE){throw "v2 size $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $CallBudgetProbe
if($LASTEXITCODE){throw "v2 call budget $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BranchBudgetProbe
if($LASTEXITCODE){throw "v2 branch budget $LASTEXITCODE"}
& $Program
if($LASTEXITCODE){throw "v2 final run $LASTEXITCODE"}
Write-Output 'verify-v2final: ok'
