.intel_syntax noprefix

# DEADWIRE V2 lane start source.
# This is assembled only by the V2 verifier for now.
# It is not linked into the default server build.

.extern dw_runtime_accept_entry
.extern dw_runtime_http_engine_entry
.extern dw_runtime_spawn_entry
.extern dw_runtime_close_handle

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

.section .text
.global dw_runtime_spawn_lanes

dw_runtime_spawn_lanes:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    test rcx, rcx
    je .bad_no_context
    mov qword ptr [rbp - 8], rcx

    mov r10, rcx
    xor eax, eax
    mov qword ptr [r10 + DW_SPAWN_ACCEPT_HANDLE], rax
    mov qword ptr [r10 + DW_SPAWN_WORK_HANDLE], rax
    mov qword ptr [r10 + DW_SPAWN_OUTPUT_HANDLE], rax

    mov rdx, qword ptr [r10 + DW_SPAWN_ACCEPT_CONTEXT_PTR]
    test rdx, rdx
    je .bad
    lea rcx, [rip + dw_runtime_accept_entry]
    mov r8, qword ptr [r10 + DW_SPAWN_ACCEPT_THREAD_ID_PTR]
    call dw_runtime_spawn_entry
    test rax, rax
    je .bad
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_SPAWN_ACCEPT_HANDLE], rax

    mov rdx, qword ptr [r10 + DW_SPAWN_WORK_CONTEXT_PTR]
    test rdx, rdx
    je .bad
    lea rcx, [rip + dw_runtime_http_engine_entry]
    mov r8, qword ptr [r10 + DW_SPAWN_WORK_THREAD_ID_PTR]
    call dw_runtime_spawn_entry
    test rax, rax
    je .bad
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_SPAWN_WORK_HANDLE], rax

    xor eax, eax
    mov qword ptr [r10 + DW_SPAWN_LAST_RESULT], rax
    leave
    ret

.bad:
    mov r10, qword ptr [rbp - 8]

    mov rcx, qword ptr [r10 + DW_SPAWN_WORK_HANDLE]
    test rcx, rcx
    je .bad_check_accept
    call dw_runtime_close_handle
    mov r10, qword ptr [rbp - 8]
    xor eax, eax
    mov qword ptr [r10 + DW_SPAWN_WORK_HANDLE], rax

.bad_check_accept:
    mov rcx, qword ptr [r10 + DW_SPAWN_ACCEPT_HANDLE]
    test rcx, rcx
    je .bad_done
    call dw_runtime_close_handle
    mov r10, qword ptr [rbp - 8]
    xor eax, eax
    mov qword ptr [r10 + DW_SPAWN_ACCEPT_HANDLE], rax

.bad_done:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_SPAWN_LAST_RESULT], rax
    leave
    ret

.bad_no_context:
    mov eax, 1
    leave
    ret
