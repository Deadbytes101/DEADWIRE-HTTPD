.intel_syntax noprefix

# DEADWIRE V2 runtime source map.
# This file is assembled by scripts/verify-runtime-source-map.ps1.
# It is not linked into the default server build yet.
# The live implementation remains src/deadwire_windows.s.

.extern send
.extern GetStdHandle
.extern WriteFile

.equ STD_OUTPUT_HANDLE, -11
.equ DW_RESPONSE_STATUS_PTR, 0
.equ DW_RESPONSE_STATUS_LEN, 8
.equ DW_RESPONSE_TYPE_PTR, 16
.equ DW_RESPONSE_TYPE_LEN, 24
.equ DW_RESPONSE_BODY_PTR, 32
.equ DW_RESPONSE_BODY_LEN, 40
.equ DW_CLIENT_SOCKET, 0
.equ DW_CLIENT_RECV_BUFFER_PTR, 8
.equ DW_CLIENT_RECV_BUFFER_CAP, 16
.equ DW_CLIENT_RESPONSE_PTR, 24

.section .rdata
.dw_header_type_prefix:
    .ascii "Connection: close\r\n"
    .ascii "Content-Type: "
.dw_header_type_prefix_end:
.dw_header_len_prefix:
    .ascii "\r\nContent-Length: "
.dw_header_len_prefix_end:
.dw_header_end:
    .ascii "\r\n\r\n"
.dw_header_end_end:

.section .bss
.align 8
.dw_len_buf:
    .skip 32
.dw_len_buf_end:

.section .text
.global dw_runtime_main
.global dw_runtime_accept_loop
.global dw_runtime_handle_client
.global dw_runtime_send_response
.global dw_runtime_send_all
.global dw_runtime_write_output
.global dw_runtime_u64_to_dec

# dw_runtime_main maps to mainCRTStartup.
dw_runtime_main:
    ret

# dw_runtime_accept_loop maps to .accept_loop.
dw_runtime_accept_loop:
    ret

# dw_runtime_handle_client maps to handle_client.
# dw_runtime_handle_client(context rcx) uses the V2 client context ABI.
dw_runtime_handle_client:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    test rcx, rcx
    je .dw_runtime_handle_client_null

    mov r10, rcx
    mov rax, qword ptr [r10 + DW_CLIENT_SOCKET]
    mov qword ptr [rbp - 8], rax
    mov rax, qword ptr [r10 + DW_CLIENT_RECV_BUFFER_PTR]
    mov rax, qword ptr [r10 + DW_CLIENT_RECV_BUFFER_CAP]
    mov rax, qword ptr [r10 + DW_CLIENT_RESPONSE_PTR]
    test rax, rax
    je .dw_runtime_handle_client_no_response
    mov qword ptr [rbp - 16], rax

    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [rbp - 16]
    call dw_runtime_send_response
    xor eax, eax
    leave
    ret

.dw_runtime_handle_client_no_response:
    mov eax, 2
    leave
    ret

.dw_runtime_handle_client_null:
    mov eax, 1
    leave
    ret

# dw_runtime_send_response(socket rcx, response rdx) maps to send_response.
dw_runtime_send_response:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov qword ptr [rbp - 8], rcx
    mov qword ptr [rbp - 16], rdx

    mov r10, qword ptr [rbp - 16]
    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [r10 + DW_RESPONSE_STATUS_PTR]
    mov r8, qword ptr [r10 + DW_RESPONSE_STATUS_LEN]
    call dw_runtime_send_all

    mov rcx, qword ptr [rbp - 8]
    lea rdx, [rip + .dw_header_type_prefix]
    mov r8, .dw_header_type_prefix_end - .dw_header_type_prefix
    call dw_runtime_send_all

    mov r10, qword ptr [rbp - 16]
    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [r10 + DW_RESPONSE_TYPE_PTR]
    mov r8, qword ptr [r10 + DW_RESPONSE_TYPE_LEN]
    call dw_runtime_send_all

    mov rcx, qword ptr [rbp - 8]
    lea rdx, [rip + .dw_header_len_prefix]
    mov r8, .dw_header_len_prefix_end - .dw_header_len_prefix
    call dw_runtime_send_all

    mov r10, qword ptr [rbp - 16]
    mov rcx, qword ptr [r10 + DW_RESPONSE_BODY_LEN]
    call dw_runtime_u64_to_dec
    mov rcx, qword ptr [rbp - 8]
    mov r8, rdx
    mov rdx, rax
    call dw_runtime_send_all

    mov rcx, qword ptr [rbp - 8]
    lea rdx, [rip + .dw_header_end]
    mov r8, .dw_header_end_end - .dw_header_end
    call dw_runtime_send_all

    mov r10, qword ptr [rbp - 16]
    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [r10 + DW_RESPONSE_BODY_PTR]
    mov r8, qword ptr [r10 + DW_RESPONSE_BODY_LEN]
    call dw_runtime_send_all

    leave
    ret

# dw_runtime_send_all(socket rcx, buffer rdx, length r8) maps to send_all.
dw_runtime_send_all:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov qword ptr [rbp - 8], rcx
    mov qword ptr [rbp - 16], rdx
    mov qword ptr [rbp - 24], r8

.dw_runtime_send_loop:
    cmp qword ptr [rbp - 24], 0
    je .dw_runtime_send_done
    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [rbp - 16]
    mov r8, qword ptr [rbp - 24]
    xor r9d, r9d
    call send
    cmp eax, 0
    jle .dw_runtime_send_done
    cdqe
    add qword ptr [rbp - 16], rax
    sub qword ptr [rbp - 24], rax
    jmp .dw_runtime_send_loop

.dw_runtime_send_done:
    leave
    ret

# dw_runtime_write_output(ptr rcx, length rdx) maps to write_stdout.
dw_runtime_write_output:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov qword ptr [rbp - 8], rcx
    mov qword ptr [rbp - 16], rdx

    mov ecx, STD_OUTPUT_HANDLE
    call GetStdHandle

    mov rcx, rax
    mov rdx, qword ptr [rbp - 8]
    mov r8, qword ptr [rbp - 16]
    lea r9, [rbp - 20]
    mov qword ptr [rsp + 32], 0
    call WriteFile

    leave
    ret

# dw_runtime_u64_to_dec(value rcx) -> rax=ptr, rdx=len
dw_runtime_u64_to_dec:
    lea r11, [rip + .dw_len_buf_end]
    xor r9, r9
    mov rax, rcx
    test rax, rax
    jne .dw_dec_loop
    dec r11
    mov byte ptr [r11], '0'
    mov rax, r11
    mov edx, 1
    ret

.dw_dec_loop:
    mov r10, 10
.dw_dec_step:
    xor rdx, rdx
    div r10
    dec r11
    add dl, '0'
    mov byte ptr [r11], dl
    inc r9
    test rax, rax
    jne .dw_dec_step
    mov rax, r11
    mov rdx, r9
    ret
