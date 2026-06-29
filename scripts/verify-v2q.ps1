$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2q.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2q.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2q.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2q.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing runtime source map: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'DW_QUEUE_HEAD',
    'DW_QUEUE_TAIL',
    'DW_QUEUE_CAPACITY',
    'DW_QUEUE_ITEMS_PTR',
    'dw_runtime_queue_push:',
    'dw_runtime_queue_pop:',
    '.dw_runtime_queue_push_full:',
    '.dw_runtime_queue_pop_empty:'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 queue logic: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 queue assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 queue symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
$RequiredSymbols = @(
    'dw_runtime_queue_push',
    'dw_runtime_queue_pop'
)

foreach ($Symbol in $RequiredSymbols) {
    if (-not $SymbolText.Contains($Symbol)) {
        throw "missing runtime object symbol: $Symbol"
    }
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.extern dw_runtime_queue_push
.extern dw_runtime_queue_pop
.extern ExitProcess

.section .data
item_a:
    .quad 0x11111111
item_b:
    .quad 0x22222222
item_c:
    .quad 0x33333333
slots:
    .quad 0
    .quad 0
queue:
    .quad 0
    .quad 0
    .quad 2
    .quad slots
bad_queue:
    .quad 0
    .quad 0
    .quad 0
    .quad slots

.section .text
mainCRTStartup:
    sub rsp, 40

    xor rcx, rcx
    lea rdx, [rip + item_a]
    call dw_runtime_queue_push
    cmp eax, 1
    jne fail

    lea rcx, [rip + bad_queue]
    lea rdx, [rip + item_a]
    call dw_runtime_queue_push
    cmp eax, 1
    jne fail

    lea rcx, [rip + queue]
    lea rdx, [rip + item_a]
    call dw_runtime_queue_push
    test eax, eax
    jne fail

    lea rcx, [rip + queue]
    lea rdx, [rip + item_b]
    call dw_runtime_queue_push
    cmp eax, 2
    jne fail

    lea rcx, [rip + queue]
    call dw_runtime_queue_pop
    lea r10, [rip + item_a]
    cmp rax, r10
    jne fail

    lea rcx, [rip + queue]
    call dw_runtime_queue_pop
    test rax, rax
    jne fail

    lea rcx, [rip + queue]
    lea rdx, [rip + item_b]
    call dw_runtime_queue_push
    test eax, eax
    jne fail

    lea rcx, [rip + queue]
    call dw_runtime_queue_pop
    lea r10, [rip + item_b]
    cmp rax, r10
    jne fail

    lea rcx, [rip + queue]
    lea rdx, [rip + item_c]
    call dw_runtime_queue_push
    test eax, eax
    jne fail

    lea rcx, [rip + queue]
    call dw_runtime_queue_pop
    lea r10, [rip + item_c]
    cmp rax, r10
    jne fail

pass:
    xor ecx, ecx
    call ExitProcess

fail:
    mov ecx, 1
    call ExitProcess
'@ | Set-Content -Encoding ASCII $HarnessPath

& as --64 -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 queue harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $ObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 queue harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 queue harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2q: ok'
