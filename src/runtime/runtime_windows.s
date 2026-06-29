.intel_syntax noprefix

# DEADWIRE V2 runtime source map.
# This file is assembled by scripts/verify-runtime-source-map.ps1.
# It is not linked into the default server build yet.
# The live implementation remains src/deadwire_windows.s.

.extern send
.extern recv
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
.equ DW_QUEUE_HEAD, 0
.equ DW_QUEUE_TAIL, 8
.equ DW_QUEUE_CAPACITY, 16
.equ DW_QUEUE_ITEMS_PTR, 24

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
.global dw_runtime_recv_request
.global dw_runtime_request_is_get
.global dw_runtime_queue_push
.global dw_runtime_queue_pop
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
    mov qword ptr [rbp - 16], rax
    mov rax, qword ptr [r10 + DW_CLIENT_RECV_BUFFER_CAP]
    mov qword ptr [rbp - 24], rax
    mov rax, qword ptr [r10 + DW_CLIENT_RESPONSE_PTR]
    test rax, rax
    je .dw_runtime_handle_client_no_response
    mov qword ptr [rbp - 32], rax

    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [rbp - 16]
    mov r8, qword ptr [rbp - 24]
    call dw_runtime_recv_request
    cmp eax, 0
    jle .dw_runtime_handle_client_recv_failed
    cdqe
    mov qword ptr [rbp - 40], rax

    mov rcx, qword ptr [rbp - 16]
    mov rdx, qword ptr [rbp - 40]
    call dw_runtime_request_is_get
    test eax, eax
    je .dw_runtime_handle_client_bad_request

    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [rbp - 32]
    call dw_runtime_send_response
    xor eax, eax
    leave
    ret

.dw_runtime_handle_client_bad_request:
    mov eax, 4
    leave
    ret

.dw_runtime_handle_client_recv_failed:
    mov eax, 3
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

# dw_runtime_recv_request(socket rcx, buffer rdx, capacity r8) maps to request receive boundary.
dw_runtime_recv_request:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    test rdx, rdx
    je .dw_runtime_recv_request_bad
    test r8, r8
    je .dw_runtime_recv_request_bad
    xor r9d, r9d
    call recv
    leave
    ret

.dw_runtime_recv_request_bad:
    mov eax, -1
    leave
    ret

# dw_runtime_request_is_get(buffer rcx, length rdx) maps to request parser boundary.
dw_runtime_request_is_get:
    test rcx, rcx
    je .dw_runtime_request_is_get_no
    cmp rdx, 3
    jb .dw_runtime_request_is_get_no
    cmp byte ptr [rcx + 0], 'G'
    jne .dw_runtime_request_is_get_no
    cmp byte ptr [rcx + 1], 'E'
    jne .dw_runtime_request_is_get_no
    cmp byte ptr [rcx + 2], 'T'
    jne .dw_runtime_request_is_get_no
    mov eax, 1
    ret

.dw_runtime_request_is_get_no:
    xor eax, eax
    ret

# dw_runtime_queue_push(queue rcx, item rdx) maps to the V2 lane handoff queue push boundary.
dw_runtime_queue_push:
    test rcx, rcx
    je .dw_runtime_queue_push_bad
    test rdx, rdx
    je .dw_runtime_queue_push_bad

    mov r8, qword ptr [rcx + DW_QUEUE_HEAD]
    mov r9, qword ptr [rcx + DW_QUEUE_TAIL]
    mov r10, qword ptr [rcx + DW_QUEUE_CAPACITY]
    test r10, r10
    je .dw_runtime_queue_push_bad
    mov r11, qword ptr [rcx + DW_QUEUE_ITEMS_PTR]
    test r11, r11
    je .dw_runtime_queue_push_bad

    mov rax, r9
    inc rax
    cmp rax, r10
    jb .dw_runtime_queue_push_next_ready
    xor eax, eax

.dw_runtime_queue_push_next_ready:
    cmp rax, r8
    je .dw_runtime_queue_push_full
    mov qword ptr [r11 + r9 * 8], rdx
    mov qword ptr [rcx + DW_QUEUE_TAIL], rax
    xor eax, eax
    ret

.dw_runtime_queue_push_full:
    mov eax, 2
    ret

.dw_runtime_queue_push_bad:
    mov eax, 1
    ret

# dw_runtime_queue_pop(queue rcx) maps to the V2 lane handoff queue pop boundary.
dw_runtime_queue_pop:
    test rcx, rcx
    je .dw_runtime_queue_pop_empty

    mov r8, qword ptr [rcx + DW_QUEUE_HEAD]
    mov r9, qword ptr [rcx + DW_QUEUE_TAIL]
    cmp r8, r9
    je .dw_runtime_queue_pop_empty
    mov r10, qword ptr [rcx + DW_QUEUE_CAPACITY]
    test r10, r10
    je .dw_runtime_queue_pop_empty
    mov r11, qword ptr [rcx + DW_QUEUE_ITEMS_PTR]
    test r11, r11
    je .dw_runtime_queue_pop_empty

    mov rax, qword ptr [r11 + r8 * 8]
    mov rdx, r8
    inc rdx
    cmp rdx, r10
    jb .dw_runtime_queue_pop_next_ready
    xor edx, edx

.dw_runtime_queue_pop_next_ready:
    mov qword ptr [rcx + DW_QUEUE_HEAD], rdx
    ret

.dw_runtime_queue_pop_empty:
    xor eax, eax
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
