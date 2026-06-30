$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_accept_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2accept.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2accept.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2accept.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2accept.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing V2 accept source: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'dw_runtime_live_accept_once:',
    'accept',
    'DW_LIVE_SOCKET',
    'DW_LIVE_LAST_RESULT',
    'DW_CLIENT_SOCKET'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 accept rule: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 accept assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 accept symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
if (-not $SymbolText.Contains('dw_runtime_live_accept_once')) {
    throw 'missing runtime object symbol: dw_runtime_live_accept_once'
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.global accept
.extern dw_runtime_live_accept_once
.extern ExitProcess

.section .data
live_ctx:
    .quad 0x11112222
    .quad 0
    .quad 0
    .quad 0
    .quad 99
closed_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 99
client_ctx:
    .quad 99
    .quad 0
    .quad 0
    .quad 0
fail_mode:
    .quad 0
accept_count:
    .quad 0
accept_socket_seen:
    .quad 0

.section .text
mainCRTStartup:
    sub rsp, 40

    xor rcx, rcx
    lea rdx, [rip + client_ctx]
    call dw_runtime_live_accept_once
    cmp eax, 1
    jne fail

    lea rcx, [rip + live_ctx]
    xor rdx, rdx
    call dw_runtime_live_accept_once
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + live_ctx + 32], 1
    jne fail

    mov qword ptr [rip + client_ctx + 0], 99
    lea rcx, [rip + closed_ctx]
    lea rdx, [rip + client_ctx]
    call dw_runtime_live_accept_once
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + closed_ctx + 32], 1
    jne fail
    cmp qword ptr [rip + client_ctx + 0], 0
    jne fail
    cmp qword ptr [rip + accept_count], 0
    jne fail

    mov qword ptr [rip + fail_mode], 1
    mov qword ptr [rip + accept_count], 0
    mov qword ptr [rip + accept_socket_seen], 0
    mov qword ptr [rip + client_ctx + 0], 99
    mov qword ptr [rip + live_ctx + 32], 99
    lea rcx, [rip + live_ctx]
    lea rdx, [rip + client_ctx]
    call dw_runtime_live_accept_once
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + live_ctx + 32], 1
    jne fail
    cmp qword ptr [rip + client_ctx + 0], 0
    jne fail
    cmp qword ptr [rip + accept_count], 1
    jne fail
    cmp qword ptr [rip + accept_socket_seen], 0x11112222
    jne fail

    mov qword ptr [rip + fail_mode], 0
    mov qword ptr [rip + accept_count], 0
    mov qword ptr [rip + accept_socket_seen], 0
    mov qword ptr [rip + client_ctx + 0], 99
    mov qword ptr [rip + live_ctx + 32], 99
    lea rcx, [rip + live_ctx]
    lea rdx, [rip + client_ctx]
    call dw_runtime_live_accept_once
    test eax, eax
    jne fail
    cmp qword ptr [rip + live_ctx + 32], 0
    jne fail
    cmp qword ptr [rip + client_ctx + 0], 0x33334444
    jne fail
    cmp qword ptr [rip + accept_count], 1
    jne fail
    cmp qword ptr [rip + accept_socket_seen], 0x11112222
    jne fail

pass:
    xor ecx, ecx
    call ExitProcess

fail:
    mov ecx, 1
    call ExitProcess

accept:
    inc qword ptr [rip + accept_count]
    mov qword ptr [rip + accept_socket_seen], rcx
    cmp qword ptr [rip + fail_mode], 1
    je accept_fail
    mov eax, 0x33334444
    ret
accept_fail:
    mov rax, -1
    ret
'@ | Set-Content -Encoding ASCII $HarnessPath

& as --64 -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 accept harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $ObjectPath -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 accept harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 accept harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2accept: ok'
