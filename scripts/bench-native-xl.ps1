param(
    [int] $Requests = 16384,
    [int] $Rounds = 5
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$BenchNative = Join-Path $PSScriptRoot 'bench-native.ps1'

if (-not (Test-Path $BenchNative)) {
    throw "bench-native-xl: missing runner: $BenchNative"
}

if ($Requests -lt 1) {
    throw 'bench-native-xl: Requests must be >= 1'
}

if ($Rounds -lt 1) {
    throw 'bench-native-xl: Rounds must be >= 1'
}

$cases = @(
    @{ Port = 19420; Path = '/health' },
    @{ Port = 19421; Path = '/missing-bench.txt' },
    @{ Port = 19422; Path = '/hello.txt' },
    @{ Port = 19423; Path = '/' }
)

Write-Host ('native-xl: requests={0} rounds={1} total_connections={2}' -f $Requests, $Rounds, ($Requests * $Rounds * $cases.Count))

foreach ($case in $cases) {
    & $BenchNative -Port $case.Port -Requests $Requests -Path $case.Path -Rounds $Rounds
    if ($LASTEXITCODE -ne 0) {
        throw "bench-native-xl: failed for path $($case.Path)"
    }
}
