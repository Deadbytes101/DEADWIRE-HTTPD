.intel_syntax noprefix

# DEADWIRE V2 live cycle source.
# This is assembled only by V2 opt-in build and verifier paths for now.
# It is not linked into the default server build.

.extern dw_runtime_live_open
.extern dw_runtime_live_close

.equ DW_LIVE_LAST_RESULT, 32

.section .text
.global dw_runtime_live_cycle_once

# dw_runtime_live_cycle_once(live_context rcx) opens and closes the live context once.
dw_runtime_live_cycle_once:
    push rbp
    mov rbp, rsp
    sub rsp, 96

    test rcx, rcx
    je .cycle_bad_no_context
    mov qword ptr [rbp - 8], rcx

    call dw_runtime_live_open
    test eax, eax
    jne .cycle_bad

    mov rcx, qword ptr [rbp - 8]
    call dw_runtime_live_close
    test eax, eax
    jne .cycle_bad

    xor eax, eax
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_LIVE_LAST_RESULT], rax
    leave
    ret

.cycle_bad:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_LIVE_LAST_RESULT], rax
    leave
    ret

.cycle_bad_no_context:
    mov eax, 1
    leave
    ret
