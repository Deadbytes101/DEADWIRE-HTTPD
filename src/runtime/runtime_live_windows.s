.intel_syntax noprefix

# DEADWIRE V2 live source.
# This is assembled only by V2 opt-in build and verifier paths for now.
# It is not linked into the default server build.

.extern WSAStartup
.extern WSACleanup
.extern socket
.extern setsockopt
.extern bind
.extern listen
.extern closesocket

.equ AF_INET, 2
.equ SOCK_STREAM, 1
.equ IPPROTO_TCP, 6
.equ SOL_SOCKET, 0xffff
.equ SO_REUSEADDR, 4
.equ INVALID_SOCKET, -1
.equ SOCKET_ERROR, -1

.equ DW_LIVE_SOCKET, 0
.equ DW_LIVE_SOCKADDR_PTR, 8
.equ DW_LIVE_SOCKADDR_LEN, 16
.equ DW_LIVE_BACKLOG, 24
.equ DW_LIVE_LAST_RESULT, 32

.section .data
reuse_one:
    .long 1

.section .bss
.align 8
live_wsadata:
    .skip 512

.section .text
.global dw_runtime_live_open

# dw_runtime_live_open(live_context rcx) opens a listening socket boundary.
dw_runtime_live_open:
    push rbp
    mov rbp, rsp
    sub rsp, 96

    test rcx, rcx
    je .live_bad_no_context
    mov qword ptr [rbp - 8], rcx

    mov r10, rcx
    xor eax, eax
    mov qword ptr [r10 + DW_LIVE_SOCKET], rax

    mov rax, qword ptr [r10 + DW_LIVE_SOCKADDR_PTR]
    test rax, rax
    je .live_bad
    mov rax, qword ptr [r10 + DW_LIVE_SOCKADDR_LEN]
    test rax, rax
    je .live_bad
    mov rax, qword ptr [r10 + DW_LIVE_BACKLOG]
    test rax, rax
    je .live_bad

    mov ecx, 0x0202
    lea rdx, [rip + live_wsadata]
    call WSAStartup
    test eax, eax
    jne .live_bad

    mov ecx, AF_INET
    mov edx, SOCK_STREAM
    mov r8d, IPPROTO_TCP
    call socket
    cmp rax, INVALID_SOCKET
    je .live_cleanup_wsa

    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_LIVE_SOCKET], rax

    mov rcx, rax
    mov edx, SOL_SOCKET
    mov r8d, SO_REUSEADDR
    lea r9, [rip + reuse_one]
    mov qword ptr [rsp + 32], 4
    call setsockopt
    cmp eax, SOCKET_ERROR
    je .live_cleanup_socket

    mov r10, qword ptr [rbp - 8]
    mov rcx, qword ptr [r10 + DW_LIVE_SOCKET]
    mov rdx, qword ptr [r10 + DW_LIVE_SOCKADDR_PTR]
    mov r8d, dword ptr [r10 + DW_LIVE_SOCKADDR_LEN]
    call bind
    cmp eax, SOCKET_ERROR
    je .live_cleanup_socket

    mov r10, qword ptr [rbp - 8]
    mov rcx, qword ptr [r10 + DW_LIVE_SOCKET]
    mov edx, dword ptr [r10 + DW_LIVE_BACKLOG]
    call listen
    cmp eax, SOCKET_ERROR
    je .live_cleanup_socket

    xor eax, eax
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_LIVE_LAST_RESULT], rax
    leave
    ret

.live_cleanup_socket:
    mov r10, qword ptr [rbp - 8]
    mov rcx, qword ptr [r10 + DW_LIVE_SOCKET]
    test rcx, rcx
    je .live_cleanup_wsa
    call closesocket
    mov r10, qword ptr [rbp - 8]
    xor eax, eax
    mov qword ptr [r10 + DW_LIVE_SOCKET], rax

.live_cleanup_wsa:
    call WSACleanup

.live_bad:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_LIVE_LAST_RESULT], rax
    leave
    ret

.live_bad_no_context:
    mov eax, 1
    leave
    ret
