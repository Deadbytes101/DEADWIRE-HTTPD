param(
    [int] $Requests = 32768,
    [int] $Rounds = 5
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'
$NoLogAsm = Join-Path $Root 'build\deadwire_windows_nolog.s'
$NoLogObj = Join-Path $Root 'build\deadwire_windows_nolog.o'
$NoLogExe = Join-Path $Root 'build\deadwire_nolog.exe'
$BenchNative = Join-Path $PSScriptRoot 'bench-native.ps1'

if (-not (Test-Path $Asm)) {
    throw "bench-native-nolog: missing generated source: $Asm"
}

if (-not (Test-Path $BenchNative)) {
    throw "bench-native-nolog: missing runner: $BenchNative"
}

if ($Requests -lt 1) {
    throw 'bench-native-nolog: Requests must be >= 1'
}

if ($Rounds -lt 1) {
    throw 'bench-native-nolog: Rounds must be >= 1'
}

$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")
$start = $s.IndexOf('# write_stdout(ptr, len)')
if ($start -lt 0) {
    throw 'bench-native-nolog: missing write_stdout comment'
}

$end = $s.IndexOf('# die(ptr, len)', $start)
if ($end -lt 0) {
    throw 'bench-native-nolog: missing die comment'
}

$stub = @'
# write_stdout(ptr, len)
write_stdout:
    ret

'@

$s = $s.Substring(0, $start) + $stub + $s.Substring($end)
[IO.File]::WriteAllText($NoLogAsm, $s.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))

$cc = if ($env:CC) { $env:CC } else { 'cc' }

& as --64 -o $NoLogObj $NoLogAsm
if ($LASTEXITCODE -ne 0) {
    throw 'bench-native-nolog: assemble failed'
}

& $cc -nostdlib -Wl,-e,mainCRTStartup -Wl,--subsystem,console -o $NoLogExe $NoLogObj -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw 'bench-native-nolog: link failed'
}

$cases = @(
    @{ Port = 19620; Path = '/health' },
    @{ Port = 19621; Path = '/missing-bench.txt' },
    @{ Port = 19622; Path = '/hello.txt' },
    @{ Port = 19623; Path = '/' }
)

Write-Host ('native-nolog: requests={0} rounds={1} total_connections={2}' -f $Requests, $Rounds, ($Requests * $Rounds * $cases.Count))

foreach ($case in $cases) {
    & $BenchNative -ServerExePath $NoLogExe -Port $case.Port -Requests $Requests -Path $case.Path -Rounds $Rounds
    if ($LASTEXITCODE -ne 0) {
        throw "bench-native-nolog: failed for path $($case.Path)"
    }
}
