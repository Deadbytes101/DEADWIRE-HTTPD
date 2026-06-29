param(
    [int] $Requests = 16384,
    [int] $Rounds = 5
)

$ErrorActionPreference = 'Stop'

$BenchNative = Join-Path $PSScriptRoot 'bench-native.ps1'

if (-not (Test-Path $BenchNative)) {
    throw "bench-native-lifecycle: missing runner: $BenchNative"
}

if ($Requests -lt 1) {
    throw 'bench-native-lifecycle: Requests must be >= 1'
}

if ($Rounds -lt 1) {
    throw 'bench-native-lifecycle: Rounds must be >= 1'
}

Write-Host ('native-lifecycle: connect-only requests={0} rounds={1} total_connections={2}' -f $Requests, $Rounds, ($Requests * $Rounds))

& $BenchNative -Port 19520 -Requests $Requests -Path '--connect-only' -Rounds $Rounds
if ($LASTEXITCODE -ne 0) {
    throw 'bench-native-lifecycle: failed'
}
