param(
    [int] $Requests = 32768,
    [int] $Rounds = 5
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$BuildQuiet = Join-Path $PSScriptRoot 'build-win-accesslog-off.ps1'
$BenchNative = Join-Path $PSScriptRoot 'bench-native.ps1'
$QuietExe = Join-Path $Root 'build\deadwire_quiet.exe'

if (-not (Test-Path $BuildQuiet)) {
    throw "bench-native-quiet: missing build script: $BuildQuiet"
}

if (-not (Test-Path $BenchNative)) {
    throw "bench-native-quiet: missing runner: $BenchNative"
}

if ($Requests -lt 1) {
    throw 'bench-native-quiet: Requests must be >= 1'
}

if ($Rounds -lt 1) {
    throw 'bench-native-quiet: Rounds must be >= 1'
}

& $BuildQuiet -OutputExe $QuietExe
if ($LASTEXITCODE -ne 0) {
    throw 'bench-native-quiet: build failed'
}

$cases = @(
    @{ Port = 19720; Path = '/health' },
    @{ Port = 19721; Path = '/missing-bench.txt' },
    @{ Port = 19722; Path = '/hello.txt' },
    @{ Port = 19723; Path = '/' }
)

Write-Host ('native-quiet: requests={0} rounds={1} total_connections={2}' -f $Requests, $Rounds, ($Requests * $Rounds * $cases.Count))

foreach ($case in $cases) {
    & $BenchNative -ServerExePath $QuietExe -Port $case.Port -Requests $Requests -Path $case.Path -Rounds $Rounds
    if ($LASTEXITCODE -ne 0) {
        throw "bench-native-quiet: failed for path $($case.Path)"
    }
}
