.intel_syntax noprefix

# DEADWIRE V2 mode source.
# This is assembled only by V2 opt-in build and verifier paths for now.
# It is not linked into the default server build.

.extern dw_runtime_bound_n

.equ DW_MODE_BOUND_CONTEXT_PTR, 0
.equ DW_MODE_LAST_RESULT, 8

.section .text
.global dw_runtime_mode_bound

# dw_runtime_mode_bound(mode_context rcx) runs the bounded V2 runtime mode once.
dw_runtime_mode_bound:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    test rcx, rcx
    je .mode_bad_no_context
    mov qword ptr [rbp - 8], rcx

    mov r10, rcx
    mov rcx, qword ptr [r10 + DW_MODE_BOUND_CONTEXT_PTR]
    test rcx, rcx
    je .mode_bad

    call dw_runtime_bound_n
    test eax, eax
    jne .mode_bad

    xor eax, eax
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_MODE_LAST_RESULT], rax
    leave
    ret

.mode_bad:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_MODE_LAST_RESULT], rax
    leave
    ret

.mode_bad_no_context:
    mov eax, 1
    leave
    ret
