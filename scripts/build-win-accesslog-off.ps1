param(
    [string] $SourceAsm = '',
    [string] $OutputExe = ''
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = if ($SourceAsm) { $SourceAsm } else { Join-Path $Root 'build\deadwire_windows_port.s' }
$AccessLogOffAsm = Join-Path $Root 'build\deadwire_windows_accesslog_off.s'
$AccessLogOffObj = Join-Path $Root 'build\deadwire_windows_accesslog_off.o'
$AccessLogOffExe = if ($OutputExe) { $OutputExe } else { Join-Path $Root 'build\deadwire_accesslog_off.exe' }

if (-not (Test-Path $Asm)) {
    throw "build-win-accesslog-off: missing generated source: $Asm"
}

$source = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")
$labels = @(
    'log_200_static',
    'log_200_health',
    'log_400',
    'log_403',
    'log_404',
    'log_405',
    'log_413',
    'log_414',
    'log_500'
)

foreach ($label in $labels) {
    $safe = [regex]::Escape($label)
    $pattern = "(?m)^\s*lea rcx, \[rip \+ $safe\]\n\s*mov rdx, ${safe}_end - $safe\n\s*call write_stdout"
    $matches = [regex]::Matches($source, $pattern).Count
    if ($matches -ne 1) {
        throw "build-win-accesslog-off: expected one write site for $label, found $matches"
    }

    $replacement = "    # access log disabled: $label`n    nop`n    nop`n    nop"
    $source = [regex]::Replace($source, $pattern, $replacement, 1)
}

[IO.File]::WriteAllText($AccessLogOffAsm, $source.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))

$cc = if ($env:CC) { $env:CC } else { 'cc' }

& as --64 -o $AccessLogOffObj $AccessLogOffAsm
if ($LASTEXITCODE -ne 0) {
    throw 'build-win-accesslog-off: assemble failed'
}

$linkArgs = @(
    '-nostdlib',
    '-Wl,-e,mainCRTStartup',
    '-Wl,--subsystem,console',
    '-o',
    $AccessLogOffExe,
    $AccessLogOffObj,
    '-lws2_32',
    '-lkernel32'
)

& $cc @linkArgs
if ($LASTEXITCODE -ne 0) {
    throw 'build-win-accesslog-off: link failed'
}

Write-Host "build-win-accesslog-off: ok $AccessLogOffExe"
