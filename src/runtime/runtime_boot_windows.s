.intel_syntax noprefix

# DEADWIRE V2 opt-in boot source.
# This is used only for build/deadwire_v2_runtime.exe.
# It is not linked into the default server build.

.extern dw_runtime_worker_init
.extern dw_runtime_run_lanes
.extern dw_runtime_mode_bound
.extern ExitProcess

.equ DW_QUEUE_HEAD, 0
.equ DW_QUEUE_TAIL, 8
.equ DW_QUEUE_CAPACITY, 16
.equ DW_QUEUE_ITEMS_PTR, 24
.equ DW_ENTRY_INPUT_QUEUE_PTR, 0
.equ DW_ENTRY_WORKER_PTR, 8
.equ DW_ENTRY_OUTPUT_QUEUE_PTR, 16
.equ DW_ENTRY_CLIENT_PTR, 24
.equ DW_ENTRY_LAST_RESULT, 32
.equ DW_SPAWN_ACCEPT_CONTEXT_PTR, 0
.equ DW_SPAWN_WORK_CONTEXT_PTR, 8
.equ DW_SPAWN_OUTPUT_CONTEXT_PTR, 16
.equ DW_SPAWN_ACCEPT_THREAD_ID_PTR, 24
.equ DW_SPAWN_WORK_THREAD_ID_PTR, 32
.equ DW_SPAWN_OUTPUT_THREAD_ID_PTR, 40
.equ DW_SPAWN_ACCEPT_HANDLE, 48
.equ DW_SPAWN_WORK_HANDLE, 56
.equ DW_SPAWN_OUTPUT_HANDLE, 64
.equ DW_SPAWN_LAST_RESULT, 72
.equ DW_LIVE_SOCKET, 0
.equ DW_LIVE_SOCKADDR_PTR, 8
.equ DW_LIVE_SOCKADDR_LEN, 16
.equ DW_LIVE_BACKLOG, 24
.equ DW_LIVE_LAST_RESULT, 32
.equ DW_TICK_LIVE_CONTEXT_PTR, 0
.equ DW_TICK_CLIENT_CONTEXT_PTR, 8
.equ DW_TICK_INPUT_QUEUE_PTR, 16
.equ DW_TICK_WORKER_PTR, 24
.equ DW_TICK_OUTPUT_QUEUE_PTR, 32
.equ DW_TICK_OUTPUT_CLIENT_PTR, 40
.equ DW_TICK_LAST_RESULT, 48
.equ DW_BOUND_TICK_CONTEXT_PTR, 0
.equ DW_BOUND_COUNT, 8
.equ DW_BOUND_COMPLETED, 16
.equ DW_BOUND_LAST_RESULT, 24
.equ DW_MODE_BOUND_CONTEXT_PTR, 0
.equ DW_MODE_LAST_RESULT, 8

.section .data
.align 8
input_items:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
output_items:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
input_queue:
    .quad 0
    .quad 0
    .quad 4
    .quad input_items
output_queue:
    .quad 0
    .quad 0
    .quad 4
    .quad output_items
worker_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
client_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
live_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
tick_ctx:
    .quad live_ctx
    .quad client_ctx
    .quad input_queue
    .quad worker_ctx
    .quad output_queue
    .quad 0
    .quad 99
bound_ctx:
    .quad tick_ctx
    .quad 0
    .quad 99
    .quad 99
mode_ctx:
    .quad bound_ctx
    .quad 99
accept_entry_ctx:
    .quad input_queue
    .quad 0
    .quad 0
    .quad client_ctx
    .quad 0
work_entry_ctx:
    .quad 0
    .quad worker_ctx
    .quad 0
    .quad 0
    .quad 0
output_entry_ctx:
    .quad 0
    .quad 0
    .quad output_queue
    .quad 0
    .quad 0
accept_tid:
    .quad 0
work_tid:
    .quad 0
output_tid:
    .quad 0
spawn_ctx:
    .quad accept_entry_ctx
    .quad work_entry_ctx
    .quad output_entry_ctx
    .quad accept_tid
    .quad work_tid
    .quad output_tid
    .quad 0
    .quad 0
    .quad 0
    .quad 99

.section .text
.global mainCRTStartup

mainCRTStartup:
    sub rsp, 40

    lea rcx, [rip + worker_ctx]
    mov edx, 1
    lea r8, [rip + input_queue]
    lea r9, [rip + output_queue]
    call dw_runtime_worker_init
    test eax, eax
    jne boot_fail

    lea rcx, [rip + spawn_ctx]
    call dw_runtime_run_lanes
    test eax, eax
    jne boot_fail

    lea rcx, [rip + mode_ctx]
    call dw_runtime_mode_bound
    test eax, eax
    jne boot_fail

boot_pass:
    xor ecx, ecx
    call ExitProcess

boot_fail:
    mov ecx, 1
    call ExitProcess
