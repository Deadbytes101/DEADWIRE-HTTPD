.intel_syntax noprefix

# DEADWIRE V2 tick source.
# This is assembled only by V2 opt-in build and verifier paths for now.
# It is not linked into the default server build.

.extern dw_runtime_live_bridge_once
.extern dw_runtime_work_step
.extern dw_runtime_output_drain

.equ DW_TICK_LIVE_CONTEXT_PTR, 0
.equ DW_TICK_CLIENT_CONTEXT_PTR, 8
.equ DW_TICK_INPUT_QUEUE_PTR, 16
.equ DW_TICK_WORKER_PTR, 24
.equ DW_TICK_OUTPUT_QUEUE_PTR, 32
.equ DW_TICK_OUTPUT_CLIENT_PTR, 40
.equ DW_TICK_LAST_RESULT, 48

.section .text
.global dw_runtime_tick_once

dw_runtime_tick_once:
    push rbp
    mov rbp, rsp
    sub rsp, 96

    test rcx, rcx
    je .tick_bad_no_context
    mov qword ptr [rbp - 8], rcx

    mov r10, rcx
    xor eax, eax
    mov qword ptr [r10 + DW_TICK_OUTPUT_CLIENT_PTR], rax

    mov rax, qword ptr [r10 + DW_TICK_LIVE_CONTEXT_PTR]
    test rax, rax
    je .tick_bad
    mov qword ptr [rbp - 16], rax

    mov rax, qword ptr [r10 + DW_TICK_CLIENT_CONTEXT_PTR]
    test rax, rax
    je .tick_bad
    mov qword ptr [rbp - 24], rax

    mov rax, qword ptr [r10 + DW_TICK_INPUT_QUEUE_PTR]
    test rax, rax
    je .tick_bad
    mov qword ptr [rbp - 32], rax

    mov rax, qword ptr [r10 + DW_TICK_WORKER_PTR]
    test rax, rax
    je .tick_bad
    mov qword ptr [rbp - 40], rax

    mov rax, qword ptr [r10 + DW_TICK_OUTPUT_QUEUE_PTR]
    test rax, rax
    je .tick_bad
    mov qword ptr [rbp - 48], rax

    mov rcx, qword ptr [rbp - 16]
    mov rdx, qword ptr [rbp - 24]
    mov r8, qword ptr [rbp - 32]
    call dw_runtime_live_bridge_once
    test eax, eax
    jne .tick_bad

    mov rcx, qword ptr [rbp - 40]
    call dw_runtime_work_step
    test eax, eax
    jne .tick_bad

    mov rcx, qword ptr [rbp - 48]
    call dw_runtime_output_drain
    test rax, rax
    je .tick_bad

    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_TICK_OUTPUT_CLIENT_PTR], rax
    xor eax, eax
    mov qword ptr [r10 + DW_TICK_LAST_RESULT], rax
    leave
    ret

.tick_bad:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_TICK_LAST_RESULT], rax
    leave
    ret

.tick_bad_no_context:
    mov eax, 1
    leave
    ret
