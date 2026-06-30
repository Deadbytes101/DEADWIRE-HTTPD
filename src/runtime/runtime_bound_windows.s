.intel_syntax noprefix

# DEADWIRE V2 bounded source.
# This is assembled only by V2 opt-in build and verifier paths for now.
# It is not linked into the default server build.

.extern dw_runtime_tick_once

.equ DW_BOUND_TICK_CONTEXT_PTR, 0
.equ DW_BOUND_COUNT, 8
.equ DW_BOUND_COMPLETED, 16
.equ DW_BOUND_LAST_RESULT, 24

.section .text
.global dw_runtime_bound_n

# dw_runtime_bound_n(bound_context rcx) runs tick_once at most count times.
dw_runtime_bound_n:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    test rcx, rcx
    je .bound_bad_no_context
    mov qword ptr [rbp - 8], rcx

    mov r10, rcx
    xor eax, eax
    mov qword ptr [r10 + DW_BOUND_COMPLETED], rax

    mov rax, qword ptr [r10 + DW_BOUND_TICK_CONTEXT_PTR]
    test rax, rax
    je .bound_bad
    mov qword ptr [rbp - 16], rax

    mov rax, qword ptr [r10 + DW_BOUND_COUNT]
    mov qword ptr [rbp - 24], rax

.bound_next:
    cmp qword ptr [rbp - 24], 0
    je .bound_ok

    mov rcx, qword ptr [rbp - 16]
    call dw_runtime_tick_once
    test eax, eax
    jne .bound_bad

    mov r10, qword ptr [rbp - 8]
    inc qword ptr [r10 + DW_BOUND_COMPLETED]
    dec qword ptr [rbp - 24]
    jmp .bound_next

.bound_ok:
    xor eax, eax
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_BOUND_LAST_RESULT], rax
    leave
    ret

.bound_bad:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_BOUND_LAST_RESULT], rax
    leave
    ret

.bound_bad_no_context:
    mov eax, 1
    leave
    ret
