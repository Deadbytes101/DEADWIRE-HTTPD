param(
    [int]$Rounds = 7,
    [int]$SmokeRequests = 8
)

$ErrorActionPreference = 'Stop'
if ($Rounds -lt 1) { throw 'Rounds must be >= 1' }
if ($SmokeRequests -lt 1) { throw 'SmokeRequests must be >= 1' }

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$BuildScript = Join-Path $RepoRoot 'scripts/build-v2-runtime.ps1'
$Program = Join-Path $RepoRoot 'build/deadwire_v2_runtime.exe'
if (!(Test-Path $BuildScript)) { throw "missing $BuildScript" }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BuildScript
if ($LASTEXITCODE) { throw "build-v2-runtime failed $LASTEXITCODE" }
if (!(Test-Path $Program)) { throw "missing $Program" }

$RunMsValues = @()
for ($Round = 1; $Round -le $Rounds; $Round++) {
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    & $Program
    $ExitCode = $LASTEXITCODE
    $Timer.Stop()
    if ($ExitCode) { throw "deadwire_v2_runtime failed $ExitCode" }
    $MsPerRun = [double]$Timer.Elapsed.TotalMilliseconds
    $UsPerRequest = ($MsPerRun * 1000.0) / [double]$SmokeRequests
    $RunMsValues += $MsPerRun
    Write-Output ("bench-v2-live: round={0} smoke-requests={1} ms/run={2:N3} us/request={3:N3}" -f $Round, $SmokeRequests, $MsPerRun, $UsPerRequest)
}

$SortedMs = $RunMsValues | Sort-Object
$Middle = [int]($SortedMs.Count / 2)
if (($SortedMs.Count % 2) -eq 0) {
    $MedianMs = ($SortedMs[$Middle - 1] + $SortedMs[$Middle]) / 2.0
} else {
    $MedianMs = $SortedMs[$Middle]
}
$MedianUsPerRequest = ($MedianMs * 1000.0) / [double]$SmokeRequests
Write-Output ("bench-v2-live-summary: rounds={0} smoke-requests-per-run={1} median-ms/run={2:N3} median-us/request={3:N3}" -f $Rounds, $SmokeRequests, $MedianMs, $MedianUsPerRequest)
