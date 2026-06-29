param(
    [string] $SourceAsm = '',
    [string] $OutputExe = ''
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Source = if ($SourceAsm) { $SourceAsm } else { Join-Path $Root 'build\deadwire_windows_port.s' }
$OutAsm = Join-Path $Root 'build\deadwire_windows_keepalive_experimental.s'
$OutObj = Join-Path $Root 'build\deadwire_windows_keepalive_experimental.o'
$OutExe = if ($OutputExe) { $OutputExe } else { Join-Path $Root 'build\deadwire_keepalive_experimental.exe' }
$CC = if ($env:CC) { $env:CC } else { 'cc' }
$AS = if ($env:AS) { $env:AS } else { 'as' }

if (-not (Test-Path $Source)) {
    throw "build-win-keepalive-experimental: missing source asm: $Source"
}

$text = Get-Content $Source -Raw
$text = $text -replace "`r`n", "`n"

$handleAt = $text.IndexOf("handle_client:")
if ($handleAt -lt 0) {
    throw 'build-win-keepalive-experimental: missing handle_client label'
}

$setTypeNeedle = "    call set_type_text`n"
$setTypeAt = $text.IndexOf($setTypeNeedle, $handleAt)
if ($setTypeAt -lt 0) {
    throw 'build-win-keepalive-experimental: missing handle_client set_type_text call'
}

$loopLabel = "`n.request_loop:`n"
if ($text.IndexOf('.request_loop:', $handleAt) -ge 0) {
    throw 'build-win-keepalive-experimental: request loop label already exists'
}
$text = $text.Substring(0, $setTypeAt) + $loopLabel + $text.Substring($setTypeAt)

$healthAt = $text.IndexOf(".health:")
$badRequestAt = $text.IndexOf(".bad_request:", $healthAt)
if ($healthAt -lt 0 -or $badRequestAt -lt $healthAt) {
    throw 'build-win-keepalive-experimental: missing health block'
}

$healthBlock = $text.Substring($healthAt, $badRequestAt - $healthAt)
$healthNeedle = "    call send_response`n    jmp .close_client"
$healthCount = [regex]::Matches($healthBlock, [regex]::Escape($healthNeedle)).Count
if ($healthCount -ne 1) {
    throw "build-win-keepalive-experimental: expected one health response close edge, found $healthCount"
}
$healthBlock = $healthBlock.Replace($healthNeedle, "    call send_response`n    jmp .request_loop")
$text = $text.Substring(0, $healthAt) + $healthBlock + $text.Substring($badRequestAt)

Set-Content -Path $OutAsm -Value ($text -replace "`n", "`r`n") -NoNewline -Encoding ascii

& $AS --64 -o $OutObj $OutAsm
if ($LASTEXITCODE -ne 0) { throw 'build-win-keepalive-experimental: assemble failed' }

$linkArgs = @(
    '-nostdlib',
    '-Wl,-e,mainCRTStartup',
    '-Wl,--subsystem,console',
    '-o', $OutExe,
    $OutObj,
    '-lws2_32',
    '-lkernel32'
)
& $CC @linkArgs
if ($LASTEXITCODE -ne 0) { throw 'build-win-keepalive-experimental: link failed' }

Write-Host "build-win-keepalive-experimental: ok $OutExe"
