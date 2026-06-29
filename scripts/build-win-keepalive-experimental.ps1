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

$anchor = @"
handle_client:
    push rbp
    mov rbp, rsp
    sub rsp, 160

    call set_type_text
"@

$replacement = @"
handle_client:
    push rbp
    mov rbp, rsp
    sub rsp, 160

.request_loop:
    call set_type_text
"@

$count = [regex]::Matches($text, [regex]::Escape($anchor)).Count
if ($count -ne 1) {
    throw "build-win-keepalive-experimental: expected one handle_client prologue, found $count"
}
$text = $text.Replace($anchor, $replacement)

$healthPattern = @"
.health:
    lea rcx, [rip + log_200_health]
    mov rdx, log_200_health_end - log_200_health
    call write_stdout
    lea rax, [rip + status_200]
    mov qword ptr [rip + response_status_ptr], rax
    mov qword ptr [rip + response_status_len], status_200_end - status_200
    lea rax, [rip + body_health]
    mov qword ptr [rip + response_body_ptr], rax
    mov qword ptr [rip + response_body_len], body_health_end - body_health
    call send_response
    jmp .close_client
"@

$healthReplacement = @"
.health:
    lea rcx, [rip + log_200_health]
    mov rdx, log_200_health_end - log_200_health
    call write_stdout
    lea rax, [rip + status_200]
    mov qword ptr [rip + response_status_ptr], rax
    mov qword ptr [rip + response_status_len], status_200_end - status_200
    lea rax, [rip + body_health]
    mov qword ptr [rip + response_body_ptr], rax
    mov qword ptr [rip + response_body_len], body_health_end - body_health
    call send_response
    jmp .request_loop
"@

$count = [regex]::Matches($text, [regex]::Escape($healthPattern)).Count
if ($count -ne 1) {
    throw "build-win-keepalive-experimental: expected one health close path, found $count"
}
$text = $text.Replace($healthPattern, $healthReplacement)

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
