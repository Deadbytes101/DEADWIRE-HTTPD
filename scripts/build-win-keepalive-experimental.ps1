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

$handleAt = $text.IndexOf('handle_client:')
if ($handleAt -lt 0) {
    throw 'build-win-keepalive-experimental: missing handle_client label'
}

$sendResponseAt = $text.IndexOf('send_response:', $handleAt)
if ($sendResponseAt -lt $handleAt) {
    throw 'build-win-keepalive-experimental: missing send_response label after handle_client'
}

$setTypeNeedle = "    call set_type_text`n"
$setTypeAt = $text.IndexOf($setTypeNeedle, $handleAt)
if ($setTypeAt -lt 0 -or $setTypeAt -gt $sendResponseAt) {
    throw 'build-win-keepalive-experimental: missing handle_client set_type_text call'
}

$loopLabel = "`n.request_loop:`n"
if ($text.IndexOf('.request_loop:', $handleAt) -ge 0) {
    throw 'build-win-keepalive-experimental: request loop label already exists'
}
$text = $text.Substring(0, $setTypeAt) + $loopLabel + $text.Substring($setTypeAt)

$sendResponseAt = $text.IndexOf('send_response:', $handleAt)
$handleBlock = $text.Substring($handleAt, $sendResponseAt - $handleAt)

$edgeNeedle = "    call send_response`n    jmp .close_client"
$edgeCount = [regex]::Matches($handleBlock, [regex]::Escape($edgeNeedle)).Count
if ($edgeCount -lt 1) {
    throw 'build-win-keepalive-experimental: no response close edges found'
}
$handleBlock = $handleBlock.Replace($edgeNeedle, "    call send_response`n    jmp .request_loop")

$fallthroughNeedle = "    call send_response`n`n.close_client:"
$fallthroughCount = [regex]::Matches($handleBlock, [regex]::Escape($fallthroughNeedle)).Count
if ($fallthroughCount -ne 1) {
    throw "build-win-keepalive-experimental: expected one fallthrough close edge, found $fallthroughCount"
}
$handleBlock = $handleBlock.Replace($fallthroughNeedle, "    call send_response`n    jmp .request_loop`n`n.close_client:")

$text = $text.Substring(0, $handleAt) + $handleBlock + $text.Substring($sendResponseAt)

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
Write-Host "build-win-keepalive-experimental: loop_edges=$edgeCount fallthrough_edges=$fallthroughCount"
