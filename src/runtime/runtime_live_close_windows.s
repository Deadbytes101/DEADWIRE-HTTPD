.intel_syntax noprefix

# DEADWIRE V2 live close source.
# This is assembled only by V2 opt-in build and verifier paths for now.
# It is not linked into the default server build.

.extern closesocket
.extern WSACleanup

.equ DW_LIVE_SOCKET, 0
.equ DW_LIVE_LAST_RESULT, 32

.section .text
.global dw_runtime_live_close

# dw_runtime_live_close(live_context rcx) closes the listening socket and cleans up Winsock.
dw_runtime_live_close:
    push rbp
    mov rbp, rsp
    sub rsp, 96

    test rcx, rcx
    je .close_bad_no_context
    mov qword ptr [rbp - 8], rcx
    xor eax, eax
    mov qword ptr [rbp - 16], rax

    mov r10, rcx
    mov rcx, qword ptr [r10 + DW_LIVE_SOCKET]
    test rcx, rcx
    je .close_finish

    call closesocket
    test eax, eax
    je .close_clear_socket
    mov qword ptr [rbp - 16], 1

.close_clear_socket:
    mov r10, qword ptr [rbp - 8]
    xor eax, eax
    mov qword ptr [r10 + DW_LIVE_SOCKET], rax

    call WSACleanup
    test eax, eax
    je .close_finish
    mov qword ptr [rbp - 16], 1

.close_finish:
    mov rax, qword ptr [rbp - 16]
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_LIVE_LAST_RESULT], rax
    test rax, rax
    je .close_ok
    mov eax, 1
    leave
    ret

.close_ok:
    xor eax, eax
    leave
    ret

.close_bad_no_context:
    mov eax, 1
    leave
    ret
