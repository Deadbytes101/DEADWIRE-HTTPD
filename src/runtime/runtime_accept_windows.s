.intel_syntax noprefix

# DEADWIRE V2 live accept source.
# This is assembled only by V2 opt-in build and verifier paths for now.
# It is not linked into the default server build.

.extern accept

.equ INVALID_SOCKET, -1
.equ DW_LIVE_SOCKET, 0
.equ DW_LIVE_LAST_RESULT, 32
.equ DW_CLIENT_SOCKET, 0

.section .text
.global dw_runtime_live_accept_once

# dw_runtime_live_accept_once(live_context rcx, client_context rdx) accepts one client.
dw_runtime_live_accept_once:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    test rcx, rcx
    je .accept_bad_no_context
    mov qword ptr [rbp - 8], rcx

    test rdx, rdx
    je .accept_bad
    mov qword ptr [rbp - 16], rdx
    xor eax, eax
    mov qword ptr [rdx + DW_CLIENT_SOCKET], rax

    mov r10, rcx
    mov rcx, qword ptr [r10 + DW_LIVE_SOCKET]
    test rcx, rcx
    je .accept_bad

    xor edx, edx
    xor r8d, r8d
    call accept
    cmp rax, INVALID_SOCKET
    je .accept_bad

    mov r10, qword ptr [rbp - 16]
    mov qword ptr [r10 + DW_CLIENT_SOCKET], rax

    xor eax, eax
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_LIVE_LAST_RESULT], rax
    leave
    ret

.accept_bad:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_LIVE_LAST_RESULT], rax
    leave
    ret

.accept_bad_no_context:
    mov eax, 1
    leave
    ret
