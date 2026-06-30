.intel_syntax noprefix

# DEADWIRE V2 bridge source.
# This is assembled only by V2 opt-in build and verifier paths for now.
# It is not linked into the default server build.

.extern dw_runtime_live_accept_once
.extern dw_runtime_accept_enqueue
.extern closesocket

.equ DW_LIVE_LAST_RESULT, 32
.equ DW_CLIENT_SOCKET, 0

.section .text
.global dw_runtime_live_bridge_once

# dw_runtime_live_bridge_once(live_context rcx, client_context rdx, input_queue r8) accepts one client and queues it.
dw_runtime_live_bridge_once:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    test rcx, rcx
    je .bridge_bad_no_context
    mov qword ptr [rbp - 8], rcx

    test rdx, rdx
    je .bridge_bad
    mov qword ptr [rbp - 16], rdx

    test r8, r8
    je .bridge_bad
    mov qword ptr [rbp - 24], r8

    call dw_runtime_live_accept_once
    test eax, eax
    jne .bridge_bad

    mov rcx, qword ptr [rbp - 24]
    mov rdx, qword ptr [rbp - 16]
    call dw_runtime_accept_enqueue
    test eax, eax
    jne .bridge_queue_bad

    xor eax, eax
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_LIVE_LAST_RESULT], rax
    leave
    ret

.bridge_queue_bad:
    mov r10, qword ptr [rbp - 16]
    mov rcx, qword ptr [r10 + DW_CLIENT_SOCKET]
    test rcx, rcx
    je .bridge_queue_bad_done
    call closesocket
    mov r10, qword ptr [rbp - 16]
    xor eax, eax
    mov qword ptr [r10 + DW_CLIENT_SOCKET], rax

.bridge_queue_bad_done:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_LIVE_LAST_RESULT], rax
    leave
    ret

.bridge_bad:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_LIVE_LAST_RESULT], rax
    leave
    ret

.bridge_bad_no_context:
    mov eax, 1
    leave
    ret
