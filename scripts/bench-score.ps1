param(
    [string] $LeftName = 'DEADWIRE',
    [string] $LeftServerExePath = '',
    [string[]] $LeftServerArgs = @(),
    [int] $LeftPort = 19095,
    [switch] $LeftExistingServer,
    [string] $RightName = 'TARGET',
    [string] $RightServerExePath = '',
    [string[]] $RightServerArgs = @(),
    [int] $RightPort = 19096,
    [switch] $RightExistingServer,
    [string] $HostName = '127.0.0.1',
    [string] $Path = '/health',
    [int] $Requests = 1024,
    [int] $Rounds = 5,
    [int] $Warmup = 16,
    [int] $StartupTimeoutMs = 5000,
    [switch] $KeepAlive
)

$ErrorActionPreference = 'Stop'
if (!$LeftName) { throw 'bench-score: LeftName is required' }
if (!$RightName) { throw 'bench-score: RightName is required' }
if ($LeftPort -lt 1 -or $LeftPort -gt 65535) { throw 'bench-score: LeftPort must be 1..65535' }
if ($RightPort -lt 1 -or $RightPort -gt 65535) { throw 'bench-score: RightPort must be 1..65535' }
if ($Requests -lt 1) { throw 'bench-score: Requests must be >= 1' }
if ($Rounds -lt 1) { throw 'bench-score: Rounds must be >= 1' }
if ($Warmup -lt 0) { throw 'bench-score: Warmup must be >= 0' }

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Bench = Join-Path $Root 'scripts/bench-external-server.ps1'
if (!(Test-Path $Bench)) { throw "bench-score: missing $Bench" }

if (!$LeftExistingServer -and !$LeftServerExePath) {
    $LeftServerExePath = Join-Path $Root 'build/deadwire.exe'
}
if (!$LeftExistingServer -and $LeftServerArgs.Count -eq 0) {
    $LeftServerArgs = @($LeftPort.ToString())
}
if (!$RightExistingServer -and !$RightServerExePath) {
    throw 'bench-score: RightServerExePath is required unless RightExistingServer is set'
}
if (!$RightExistingServer -and $RightServerArgs.Count -eq 0) {
    $RightServerArgs = @($RightPort.ToString())
}

function Run-OneServerBench(
    [string] $Name,
    [string] $ServerExePath,
    [string[]] $ServerArgs,
    [int] $Port,
    [bool] $ExistingServer
) {
    $Call = @{
        HostName = $HostName
        Port = $Port
        Path = $Path
        Requests = $Requests
        Rounds = $Rounds
        Warmup = $Warmup
        StartupTimeoutMs = $StartupTimeoutMs
    }
    if ($KeepAlive) { $Call.KeepAlive = $true }
    if ($ExistingServer) {
        $Call.ExistingServer = $true
    } else {
        $Call.ServerExePath = $ServerExePath
        $Call.ServerArgs = $ServerArgs
    }

    Write-Output "bench-score-start: name=$Name port=$Port path=$Path requests=$Requests rounds=$Rounds"
    $Output = & $Bench @Call
    $Output | ForEach-Object { Write-Output $_ }
    $Text = $Output -join "`n"
    $Match = [regex]::Match($Text, 'native-bench: .*median_rps=([0-9.]+).*median_avg_ms=([0-9.]+)')
    if (!$Match.Success) { throw "bench-score: missing native bench summary for $Name" }

    return [pscustomobject]@{
        Name = $Name
        Rps = [double]$Match.Groups[1].Value
        AvgMs = [double]$Match.Groups[2].Value
    }
}

$Left = Run-OneServerBench $LeftName $LeftServerExePath $LeftServerArgs $LeftPort ([bool]$LeftExistingServer)
$Right = Run-OneServerBench $RightName $RightServerExePath $RightServerArgs $RightPort ([bool]$RightExistingServer)

if ($Left.Rps -ge $Right.Rps) {
    $Winner = $Left.Name
    $RpsRatio = $Left.Rps / [Math]::Max($Right.Rps, 0.000001)
    $AvgRatio = $Right.AvgMs / [Math]::Max($Left.AvgMs, 0.000001)
} else {
    $Winner = $Right.Name
    $RpsRatio = $Right.Rps / [Math]::Max($Left.Rps, 0.000001)
    $AvgRatio = $Left.AvgMs / [Math]::Max($Right.AvgMs, 0.000001)
}

Write-Output ("bench-score: left={0} left_rps={1:N2} left_avg_ms={2:N3} right={3} right_rps={4:N2} right_avg_ms={5:N3} winner={6} rps_ratio={7:N3} latency_ratio={8:N3}" -f $Left.Name, $Left.Rps, $Left.AvgMs, $Right.Name, $Right.Rps, $Right.AvgMs, $Winner, $RpsRatio, $AvgRatio)
