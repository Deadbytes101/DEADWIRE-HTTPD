$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$BuildDir = Join-Path $RepoRoot 'build'
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$OutPath = Join-Path $BuildDir 'deadwire_v2_runtime_hot.s'

if (-not (Test-Path $SourcePath)) {
    throw "missing V2 runtime source: $SourcePath"
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath

$AcceptOld = @'
# dw_runtime_accept_enqueue(input_queue rcx, client rdx) maps to the accept lane handoff boundary.
dw_runtime_accept_enqueue:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    call dw_runtime_queue_push
    leave
    ret
'@

$AcceptNew = @'
# dw_runtime_accept_enqueue(input_queue rcx, client rdx) maps to the accept lane handoff boundary.
# V2 build keeps this wrapper frame-free: tail-call straight into queue push.
dw_runtime_accept_enqueue:
    jmp dw_runtime_queue_push
'@

$DrainOld = @'
# dw_runtime_output_drain(output_queue rcx) maps to one output lane drain boundary.
dw_runtime_output_drain:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    call dw_runtime_queue_pop
    leave
    ret
'@

$DrainNew = @'
# dw_runtime_output_drain(output_queue rcx) maps to one output drain helper.
# V2 build keeps this helper frame-free: tail-call straight into queue pop.
dw_runtime_output_drain:
    jmp dw_runtime_queue_pop
'@

$TakeOld = @'
# dw_runtime_worker_take(worker rcx) pops one client context from the input lane queue.
dw_runtime_worker_take:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    test rcx, rcx
    je .dw_runtime_worker_take_empty
    mov qword ptr [rbp - 8], rcx
    mov rcx, qword ptr [rcx + DW_WORKER_INPUT_QUEUE_PTR]
    test rcx, rcx
    je .dw_runtime_worker_take_empty
    call dw_runtime_queue_pop
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_WORKER_CURRENT_CLIENT_PTR], rax
    leave
    ret

.dw_runtime_worker_take_empty:
    xor eax, eax
    leave
    ret
'@

$TakeNew = @'
# dw_runtime_worker_take(worker rcx) pops one client context from the input lane queue.
# V2 build inlines queue-pop for this hot helper and returns rcx as worker on non-null paths.
dw_runtime_worker_take:
    test rcx, rcx
    je .dw_runtime_worker_take_empty
    mov r10, rcx
    mov rcx, qword ptr [r10 + DW_WORKER_INPUT_QUEUE_PTR]
    test rcx, rcx
    je .dw_runtime_worker_take_empty_set
    mov r8, qword ptr [rcx + DW_QUEUE_HEAD]
    mov r9, qword ptr [rcx + DW_QUEUE_TAIL]
    cmp r8, r9
    je .dw_runtime_worker_take_empty_set
    mov rdx, qword ptr [rcx + DW_QUEUE_CAPACITY]
    test rdx, rdx
    je .dw_runtime_worker_take_empty_set
    mov r11, qword ptr [rcx + DW_QUEUE_ITEMS_PTR]
    test r11, r11
    je .dw_runtime_worker_take_empty_set
    mov rax, qword ptr [r11 + r8 * 8]
    mov qword ptr [r10 + DW_WORKER_CURRENT_CLIENT_PTR], rax
    inc r8
    cmp r8, rdx
    jb .dw_runtime_worker_take_next_ready
    xor r8d, r8d
.dw_runtime_worker_take_next_ready:
    mov qword ptr [rcx + DW_QUEUE_HEAD], r8
    mov rcx, r10
    ret
.dw_runtime_worker_take_empty_set:
    mov qword ptr [r10 + DW_WORKER_CURRENT_CLIENT_PTR], 0
    mov rcx, r10
.dw_runtime_worker_take_empty:
    xor eax, eax
    ret
'@

$CompleteOld = @'
# dw_runtime_worker_complete(worker rcx, client rdx) pushes one completed client context to the output lane queue.
dw_runtime_worker_complete:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    test rcx, rcx
    je .dw_runtime_worker_complete_bad
    test rdx, rdx
    je .dw_runtime_worker_complete_bad
    mov qword ptr [rbp - 8], rcx
    mov rcx, qword ptr [rcx + DW_WORKER_OUTPUT_QUEUE_PTR]
    test rcx, rcx
    je .dw_runtime_worker_complete_bad
    call dw_runtime_queue_push
    test eax, eax
    jne .dw_runtime_worker_complete_done
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_WORKER_CURRENT_CLIENT_PTR], 0
    inc qword ptr [r10 + DW_WORKER_PROCESSED_COUNT]

.dw_runtime_worker_complete_done:
    leave
    ret

.dw_runtime_worker_complete_bad:
    mov eax, 1
    leave
    ret
'@

$CompleteNew = @'
# dw_runtime_worker_complete(worker rcx, client rdx) pushes one completed client context to the output lane queue.
# V2 build inlines queue-push for this hot helper.
dw_runtime_worker_complete:
    test rcx, rcx
    je .dw_runtime_worker_complete_bad
    test rdx, rdx
    je .dw_runtime_worker_complete_bad
    mov r10, rcx
    mov rcx, qword ptr [r10 + DW_WORKER_OUTPUT_QUEUE_PTR]
    test rcx, rcx
    je .dw_runtime_worker_complete_bad
    mov r8, qword ptr [rcx + DW_QUEUE_HEAD]
    mov r9, qword ptr [rcx + DW_QUEUE_TAIL]
    mov r11, qword ptr [rcx + DW_QUEUE_CAPACITY]
    test r11, r11
    je .dw_runtime_worker_complete_bad
    mov rax, r9
    inc rax
    cmp rax, r11
    jb .dw_runtime_worker_complete_next_ready
    xor eax, eax
.dw_runtime_worker_complete_next_ready:
    cmp rax, r8
    je .dw_runtime_worker_complete_full
    mov r11, qword ptr [rcx + DW_QUEUE_ITEMS_PTR]
    test r11, r11
    je .dw_runtime_worker_complete_bad
    mov qword ptr [r11 + r9 * 8], rdx
    mov qword ptr [rcx + DW_QUEUE_TAIL], rax
    mov qword ptr [r10 + DW_WORKER_CURRENT_CLIENT_PTR], 0
    inc qword ptr [r10 + DW_WORKER_PROCESSED_COUNT]
    xor eax, eax
    ret
.dw_runtime_worker_complete_full:
    mov eax, 2
    ret
.dw_runtime_worker_complete_bad:
    mov eax, 1
    ret
'@

$WorkStepOld = @'
# dw_runtime_work_step(worker rcx) maps to one work lane handoff step.
dw_runtime_work_step:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    test rcx, rcx
    je .dw_runtime_work_step_idle
    mov qword ptr [rbp - 8], rcx
    call dw_runtime_worker_take
    test rax, rax
    je .dw_runtime_work_step_idle
    mov rcx, qword ptr [rbp - 8]
    mov rdx, rax
    call dw_runtime_worker_complete
    leave
    ret

.dw_runtime_work_step_idle:
    mov eax, 1
    leave
    ret
'@

$WorkStepNew = @'
# dw_runtime_work_step(worker rcx) maps to one work lane handoff step.
# V2 build keeps this step frame-free; worker_take returns rcx as the worker on non-null paths.
dw_runtime_work_step:
    test rcx, rcx
    je .dw_runtime_work_step_idle
    call dw_runtime_worker_take
    test rax, rax
    je .dw_runtime_work_step_idle
    mov rdx, rax
    call dw_runtime_worker_complete
    ret
.dw_runtime_work_step_idle:
    mov eax, 1
    ret
'@

$Hot = $Source
$Hot = $Hot.Replace($AcceptOld, $AcceptNew)
$Hot = $Hot.Replace($DrainOld, $DrainNew)
$Hot = $Hot.Replace($TakeOld, $TakeNew)
$Hot = $Hot.Replace($CompleteOld, $CompleteNew)
$Hot = $Hot.Replace($WorkStepOld, $WorkStepNew)

if ($Hot -eq $Source) {
    throw 'V2 thin runtime generation made no changes'
}
if (-not $Hot.Contains('dw_runtime_accept_enqueue:')) {
    throw 'generated source missing accept enqueue symbol'
}
foreach ($Needle in @(
    'jmp dw_runtime_queue_push',
    'jmp dw_runtime_queue_pop',
    'dw_runtime_worker_take_next_ready:',
    'dw_runtime_worker_complete_next_ready:',
    'dw_runtime_work_step_idle:'
)) {
    if (-not $Hot.Contains($Needle)) {
        throw "generated source missing hot-path needle: $Needle"
    }
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutPath, $Hot, $Utf8NoBom)
Write-Output "gen-v2-runtime-hot: ok $OutPath"
