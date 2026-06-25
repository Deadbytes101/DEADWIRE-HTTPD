.intel_syntax noprefix
.global mainCRTStartup

.extern WSAStartup
.extern WSACleanup
.extern socket
.extern setsockopt
.extern bind
.extern listen
.extern accept
.extern recv
.extern send
.extern closesocket
.extern ExitProcess
.extern GetStdHandle
.extern WriteFile
.extern CreateFileA
.extern ReadFile
.extern GetFileSizeEx
.extern CloseHandle

.equ AF_INET,              2
.equ SOCK_STREAM,          1
.equ IPPROTO_TCP,          6
.equ SOL_SOCKET,           0xffff
.equ SO_REUSEADDR,         4
.equ INVALID_SOCKET,       -1
.equ SOCKET_ERROR,         -1

.equ STD_OUTPUT_HANDLE,    -11
.equ GENERIC_READ,         0x80000000
.equ FILE_SHARE_READ,      1
.equ OPEN_EXISTING,        3
.equ FILE_ATTRIBUTE_NORMAL,0x80
.equ INVALID_HANDLE_VALUE, -1

.equ REQ_CAP,              4096
.equ PATH_CAP,             512
.equ FILE_CAP,             65536

.section .rdata
banner:
    .ascii "DEADWIRE HTTPD v0.3.0 ACCESS LOG\r\n"
    .ascii "windows x86-64 assembly / WinSock2 + Kernel32 / no HTTP framework\r\n"
    .ascii "listening on http://127.0.0.1:18080\r\n"
banner_end:

fatal_wsa:    .ascii "fatal: WSAStartup failed\r\n"
fatal_wsa_end:
fatal_socket: .ascii "fatal: socket failed\r\n"
fatal_socket_end:
fatal_bind:   .ascii "fatal: bind failed; is port 18080 already in use?\r\n"
fatal_bind_end:
fatal_listen: .ascii "fatal: listen failed\r\n"
fatal_listen_end:

status_200: .ascii "HTTP/1.0 200 OK\r\n"
status_200_end:
status_400: .ascii "HTTP/1.0 400 Bad Request\r\n"
status_400_end:
status_403: .ascii "HTTP/1.0 403 Forbidden\r\n"
status_403_end:
status_404: .ascii "HTTP/1.0 404 Not Found\r\n"
status_404_end:
status_405: .ascii "HTTP/1.0 405 Method Not Allowed\r\n"
status_405_end:
status_413: .ascii "HTTP/1.0 413 Payload Too Large\r\n"
status_413_end:
status_414: .ascii "HTTP/1.0 414 URI Too Long\r\n"
status_414_end:
status_500: .ascii "HTTP/1.0 500 Internal Server Error\r\n"
status_500_end:

header_type_prefix:
    .ascii "Connection: close\r\n"
    .ascii "Content-Type: "
header_type_prefix_end:
header_len_prefix: .ascii "\r\nContent-Length: "
header_len_prefix_end:
header_end: .ascii "\r\n\r\n"
header_end_end:

ct_text: .ascii "text/plain; charset=utf-8"
ct_text_end:
ct_html: .ascii "text/html; charset=utf-8"
ct_html_end:
ct_css: .ascii "text/css; charset=utf-8"
ct_css_end:
ct_js: .ascii "application/javascript; charset=utf-8"
ct_js_end:
ct_svg: .ascii "image/svg+xml; charset=utf-8"
ct_svg_end:

body_health: .ascii "deadwire: ok\n"
body_health_end:
body_400: .ascii "400 bad request\n"
body_400_end:
body_403: .ascii "403 forbidden\n"
body_403_end:
body_404: .ascii "404 not found\n"
body_404_end:
body_405: .ascii "405 method not allowed\n"
body_405_end:
body_413: .ascii "413 file too large\n"
body_413_end:
body_414: .ascii "414 uri too long\n"
body_414_end:
body_500: .ascii "500 internal server error\n"
body_500_end:

log_200_static: .ascii "access 200 static\r\n"
log_200_static_end:
log_200_health: .ascii "access 200 /health\r\n"
log_200_health_end:
log_400: .ascii "access 400 bad-request\r\n"
log_400_end:
log_403: .ascii "access 403 forbidden\r\n"
log_403_end:
log_404: .ascii "access 404 not-found\r\n"
log_404_end:
log_405: .ascii "access 405 method\r\n"
log_405_end:
log_413: .ascii "access 413 too-large\r\n"
log_413_end:
log_414: .ascii "access 414 uri-too-long\r\n"
log_414_end:
log_500: .ascii "access 500 file-error\r\n"
log_500_end:

public_prefix: .ascii "public"
public_prefix_end:
index_path: .asciz "public\\index.html"
health_path: .ascii "/health"
health_path_end:

sockaddr_in:
    .word AF_INET
    .word 0xa046              # port 18080 in network byte order
    .long 0x0100007f          # 127.0.0.1
    .zero 8
sockaddr_in_end:

.section .data
reuse_one: .long 1

.section .bss
.align 8
server_socket: .quad 0
current_client: .quad 0
current_file: .quad 0
response_status_ptr: .quad 0
response_status_len: .quad 0
response_body_ptr: .quad 0
response_body_len: .quad 0
response_type_ptr: .quad 0
response_type_len: .quad 0
file_size: .quad 0
bytes_done: .long 0
written_done: .long 0
wsadata: .skip 512
request_buf: .skip REQ_CAP
path_buf: .skip PATH_CAP
file_buf: .skip FILE_CAP
len_buf: .skip 32
len_buf_end:

.section .text
mainCRTStartup:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    lea rcx, [rip + banner]
    mov rdx, banner_end - banner
    call write_stdout

    mov ecx, 0x0202
    lea rdx, [rip + wsadata]
    call WSAStartup
    test eax, eax
    jne .die_wsa

    mov ecx, AF_INET
    mov edx, SOCK_STREAM
    mov r8d, IPPROTO_TCP
    call socket
    cmp rax, INVALID_SOCKET
    je .die_socket
    mov qword ptr [rip + server_socket], rax

    sub rsp, 16
    mov rcx, qword ptr [rip + server_socket]
    mov edx, SOL_SOCKET
    mov r8d, SO_REUSEADDR
    lea r9, [rip + reuse_one]
    mov qword ptr [rsp + 32], 4
    call setsockopt
    add rsp, 16

    mov rcx, qword ptr [rip + server_socket]
    lea rdx, [rip + sockaddr_in]
    mov r8d, sockaddr_in_end - sockaddr_in
    call bind
    cmp eax, SOCKET_ERROR
    je .die_bind

    mov rcx, qword ptr [rip + server_socket]
    mov edx, 16
    call listen
    cmp eax, SOCKET_ERROR
    je .die_listen

.accept_loop:
    mov rcx, qword ptr [rip + server_socket]
    xor rdx, rdx
    xor r8d, r8d
    call accept
    cmp rax, INVALID_SOCKET
    je .accept_loop

    mov qword ptr [rip + current_client], rax
    call handle_client
    jmp .accept_loop

.die_wsa:
    lea rcx, [rip + fatal_wsa]
    mov rdx, fatal_wsa_end - fatal_wsa
    call die
.die_socket:
    lea rcx, [rip + fatal_socket]
    mov rdx, fatal_socket_end - fatal_socket
    call die
.die_bind:
    lea rcx, [rip + fatal_bind]
    mov rdx, fatal_bind_end - fatal_bind
    call die
.die_listen:
    lea rcx, [rip + fatal_listen]
    mov rdx, fatal_listen_end - fatal_listen
    call die

# handle_client() uses current_client
handle_client:
    push rbp
    mov rbp, rsp
    sub rsp, 160

    call set_type_text

    mov rcx, qword ptr [rip + current_client]
    lea rdx, [rip + request_buf]
    mov r8d, REQ_CAP
    xor r9d, r9d
    call recv
    cmp eax, 0
    jle .close_client

    mov qword ptr [rbp - 8], rax       # request length
    cmp rax, 5
    jb .bad_request

    lea r10, [rip + request_buf]
    cmp byte ptr [r10 + 0], 'G'
    jne .method_not_allowed
    cmp byte ptr [r10 + 1], 'E'
    jne .method_not_allowed
    cmp byte ptr [r10 + 2], 'T'
    jne .method_not_allowed
    cmp byte ptr [r10 + 3], ' '
    jne .method_not_allowed

    lea r10, [rip + request_buf + 4]   # path start
    mov qword ptr [rbp - 16], r10
    mov r11, qword ptr [rbp - 8]
    sub r11, 4
    mov qword ptr [rbp - 24], r11      # max scan length
    mov qword ptr [rbp - 32], 0        # path length

    cmp byte ptr [r10], '/'
    jne .forbidden

.scan_path:
    mov rax, qword ptr [rbp - 32]
    cmp rax, qword ptr [rbp - 24]
    jae .bad_request

    mov r10, qword ptr [rbp - 16]
    mov al, byte ptr [r10 + rax]
    cmp al, ' '
    je .path_ready

    cmp al, 32
    jb .forbidden
    cmp al, 127
    je .forbidden
    cmp al, '\\'
    je .forbidden
    cmp al, '%'
    je .forbidden

    cmp al, '.'
    jne .not_dot
    mov rcx, qword ptr [rbp - 32]
    inc rcx
    cmp rcx, qword ptr [rbp - 24]
    jae .not_dot
    mov r10, qword ptr [rbp - 16]
    cmp byte ptr [r10 + rcx], '.'
    je .forbidden
.not_dot:
    inc qword ptr [rbp - 32]
    cmp qword ptr [rbp - 32], 500
    ja .uri_too_long
    jmp .scan_path

.path_ready:
    cmp qword ptr [rbp - 32], 0
    je .bad_request

    cmp qword ptr [rbp - 32], 7
    jne .not_health
    mov r10, qword ptr [rbp - 16]
    cmp byte ptr [r10 + 0], '/'
    jne .not_health
    cmp byte ptr [r10 + 1], 'h'
    jne .not_health
    cmp byte ptr [r10 + 2], 'e'
    jne .not_health
    cmp byte ptr [r10 + 3], 'a'
    jne .not_health
    cmp byte ptr [r10 + 4], 'l'
    jne .not_health
    cmp byte ptr [r10 + 5], 't'
    jne .not_health
    cmp byte ptr [r10 + 6], 'h'
    je .health
.not_health:
    cmp qword ptr [rbp - 32], 1
    jne .build_public_path
    mov r10, qword ptr [rbp - 16]
    cmp byte ptr [r10], '/'
    jne .build_public_path

    lea rdi, [rip + path_buf]
    lea rsi, [rip + index_path]
.copy_index:
    lodsb
    stosb
    test al, al
    jne .copy_index
    jmp .serve_file

.build_public_path:
    lea rdi, [rip + path_buf]
    lea rsi, [rip + public_prefix]
    mov rcx, public_prefix_end - public_prefix
    rep movsb

    mov rsi, qword ptr [rbp - 16]
    mov rcx, qword ptr [rbp - 32]
.copy_path:
    test rcx, rcx
    jz .path_copied
    lodsb
    cmp al, '/'
    jne .path_char_ok
    mov al, '\\'
.path_char_ok:
    stosb
    dec rcx
    jmp .copy_path
.path_copied:
    mov byte ptr [rdi], 0

.serve_file:
    lea rcx, [rip + path_buf]
    mov edx, GENERIC_READ
    mov r8d, FILE_SHARE_READ
    xor r9d, r9d
    mov qword ptr [rsp + 32], OPEN_EXISTING
    mov qword ptr [rsp + 40], FILE_ATTRIBUTE_NORMAL
    mov qword ptr [rsp + 48], 0
    call CreateFileA
    cmp rax, INVALID_HANDLE_VALUE
    je .not_found
    mov qword ptr [rip + current_file], rax

    mov rcx, qword ptr [rip + current_file]
    lea rdx, [rip + file_size]
    call GetFileSizeEx
    test eax, eax
    je .file_error

    mov rax, qword ptr [rip + file_size]
    cmp rax, FILE_CAP
    ja .file_too_large

    mov rcx, qword ptr [rip + current_file]
    lea rdx, [rip + file_buf]
    mov r8d, dword ptr [rip + file_size]
    lea r9, [rip + bytes_done]
    mov qword ptr [rsp + 32], 0
    call ReadFile
    test eax, eax
    je .file_error

    mov rcx, qword ptr [rip + current_file]
    call CloseHandle

    lea rcx, [rip + path_buf]
    call detect_content_type

    lea rcx, [rip + log_200_static]
    mov rdx, log_200_static_end - log_200_static
    call write_stdout

    lea rax, [rip + status_200]
    mov qword ptr [rip + response_status_ptr], rax
    mov qword ptr [rip + response_status_len], status_200_end - status_200
    lea rax, [rip + file_buf]
    mov qword ptr [rip + response_body_ptr], rax
    mov eax, dword ptr [rip + bytes_done]
    mov qword ptr [rip + response_body_len], rax
    call send_response
    jmp .close_client

.health:
    lea rcx, [rip + log_200_health]
    mov rdx, log_200_health_end - log_200_health
    call write_stdout
    lea rax, [rip + status_200]
    mov qword ptr [rip + response_status_ptr], rax
    mov qword ptr [rip + response_status_len], status_200_end - status_200
    lea rax, [rip + body_health]
    mov qword ptr [rip + response_body_ptr], rax
    mov qword ptr [rip + response_body_len], body_health_end - body_health
    call send_response
    jmp .close_client

.bad_request:
    lea rcx, [rip + log_400]
    mov rdx, log_400_end - log_400
    call write_stdout
    lea rax, [rip + status_400]
    mov qword ptr [rip + response_status_ptr], rax
    mov qword ptr [rip + response_status_len], status_400_end - status_400
    lea rax, [rip + body_400]
    mov qword ptr [rip + response_body_ptr], rax
    mov qword ptr [rip + response_body_len], body_400_end - body_400
    call send_response
    jmp .close_client
.forbidden:
    lea rcx, [rip + log_403]
    mov rdx, log_403_end - log_403
    call write_stdout
    lea rax, [rip + status_403]
    mov qword ptr [rip + response_status_ptr], rax
    mov qword ptr [rip + response_status_len], status_403_end - status_403
    lea rax, [rip + body_403]
    mov qword ptr [rip + response_body_ptr], rax
    mov qword ptr [rip + response_body_len], body_403_end - body_403
    call send_response
    jmp .close_client
.not_found:
    lea rcx, [rip + log_404]
    mov rdx, log_404_end - log_404
    call write_stdout
    lea rax, [rip + status_404]
    mov qword ptr [rip + response_status_ptr], rax
    mov qword ptr [rip + response_status_len], status_404_end - status_404
    lea rax, [rip + body_404]
    mov qword ptr [rip + response_body_ptr], rax
    mov qword ptr [rip + response_body_len], body_404_end - body_404
    call send_response
    jmp .close_client
.method_not_allowed:
    lea rcx, [rip + log_405]
    mov rdx, log_405_end - log_405
    call write_stdout
    lea rax, [rip + status_405]
    mov qword ptr [rip + response_status_ptr], rax
    mov qword ptr [rip + response_status_len], status_405_end - status_405
    lea rax, [rip + body_405]
    mov qword ptr [rip + response_body_ptr], rax
    mov qword ptr [rip + response_body_len], body_405_end - body_405
    call send_response
    jmp .close_client
.file_too_large:
    mov rcx, qword ptr [rip + current_file]
    call CloseHandle
    lea rcx, [rip + log_413]
    mov rdx, log_413_end - log_413
    call write_stdout
    lea rax, [rip + status_413]
    mov qword ptr [rip + response_status_ptr], rax
    mov qword ptr [rip + response_status_len], status_413_end - status_413
    lea rax, [rip + body_413]
    mov qword ptr [rip + response_body_ptr], rax
    mov qword ptr [rip + response_body_len], body_413_end - body_413
    call send_response
    jmp .close_client
.uri_too_long:
    lea rcx, [rip + log_414]
    mov rdx, log_414_end - log_414
    call write_stdout
    lea rax, [rip + status_414]
    mov qword ptr [rip + response_status_ptr], rax
    mov qword ptr [rip + response_status_len], status_414_end - status_414
    lea rax, [rip + body_414]
    mov qword ptr [rip + response_body_ptr], rax
    mov qword ptr [rip + response_body_len], body_414_end - body_414
    call send_response
    jmp .close_client
.file_error:
    mov rcx, qword ptr [rip + current_file]
    call CloseHandle
    lea rcx, [rip + log_500]
    mov rdx, log_500_end - log_500
    call write_stdout
    lea rax, [rip + status_500]
    mov qword ptr [rip + response_status_ptr], rax
    mov qword ptr [rip + response_status_len], status_500_end - status_500
    lea rax, [rip + body_500]
    mov qword ptr [rip + response_body_ptr], rax
    mov qword ptr [rip + response_body_len], body_500_end - body_500
    call send_response

.close_client:
    mov rcx, qword ptr [rip + current_client]
    call closesocket
    leave
    ret

# send_response() uses response_* globals and current_client
send_response:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov rcx, qword ptr [rip + current_client]
    mov rdx, qword ptr [rip + response_status_ptr]
    mov r8, qword ptr [rip + response_status_len]
    call send_all

    mov rcx, qword ptr [rip + current_client]
    lea rdx, [rip + header_type_prefix]
    mov r8, header_type_prefix_end - header_type_prefix
    call send_all

    mov rcx, qword ptr [rip + current_client]
    mov rdx, qword ptr [rip + response_type_ptr]
    mov r8, qword ptr [rip + response_type_len]
    call send_all

    mov rcx, qword ptr [rip + current_client]
    lea rdx, [rip + header_len_prefix]
    mov r8, header_len_prefix_end - header_len_prefix
    call send_all

    mov rcx, qword ptr [rip + response_body_len]
    call u64_to_dec
    mov rcx, qword ptr [rip + current_client]
    mov r8, rdx
    mov rdx, rax
    call send_all

    mov rcx, qword ptr [rip + current_client]
    lea rdx, [rip + header_end]
    mov r8, header_end_end - header_end
    call send_all

    mov rcx, qword ptr [rip + current_client]
    mov rdx, qword ptr [rip + response_body_ptr]
    mov r8, qword ptr [rip + response_body_len]
    call send_all

    leave
    ret

# detect_content_type(path_ptr in rcx)
detect_content_type:
    push rbx
    sub rsp, 32

    call set_type_text
    mov rbx, rcx
    xor r8, r8
.len_loop:
    cmp r8, PATH_CAP
    jae .done
    cmp byte ptr [rbx + r8], 0
    je .len_done
    inc r8
    jmp .len_loop
.len_done:
    cmp r8, 5
    jb .check_4
    lea rdx, [rbx + r8 - 5]
    cmp byte ptr [rdx + 0], '.'
    jne .check_4
    cmp byte ptr [rdx + 1], 'h'
    jne .check_4
    cmp byte ptr [rdx + 2], 't'
    jne .check_4
    cmp byte ptr [rdx + 3], 'm'
    jne .check_4
    cmp byte ptr [rdx + 4], 'l'
    jne .check_4
    call set_type_html
    jmp .done
.check_4:
    cmp r8, 4
    jb .check_3
    lea rdx, [rbx + r8 - 4]
    cmp byte ptr [rdx + 0], '.'
    jne .check_css
    cmp byte ptr [rdx + 1], 'h'
    jne .check_css
    cmp byte ptr [rdx + 2], 't'
    jne .check_css
    cmp byte ptr [rdx + 3], 'm'
    jne .check_css
    call set_type_html
    jmp .done
.check_css:
    cmp byte ptr [rdx + 0], '.'
    jne .check_svg
    cmp byte ptr [rdx + 1], 'c'
    jne .check_svg
    cmp byte ptr [rdx + 2], 's'
    jne .check_svg
    cmp byte ptr [rdx + 3], 's'
    jne .check_svg
    call set_type_css
    jmp .done
.check_svg:
    cmp byte ptr [rdx + 0], '.'
    jne .check_3
    cmp byte ptr [rdx + 1], 's'
    jne .check_3
    cmp byte ptr [rdx + 2], 'v'
    jne .check_3
    cmp byte ptr [rdx + 3], 'g'
    jne .check_3
    call set_type_svg
    jmp .done
.check_3:
    cmp r8, 3
    jb .done
    lea rdx, [rbx + r8 - 3]
    cmp byte ptr [rdx + 0], '.'
    jne .done
    cmp byte ptr [rdx + 1], 'j'
    jne .done
    cmp byte ptr [rdx + 2], 's'
    jne .done
    call set_type_js
.done:
    add rsp, 32
    pop rbx
    ret

set_type_text:
    lea rax, [rip + ct_text]
    mov qword ptr [rip + response_type_ptr], rax
    mov qword ptr [rip + response_type_len], ct_text_end - ct_text
    ret
set_type_html:
    lea rax, [rip + ct_html]
    mov qword ptr [rip + response_type_ptr], rax
    mov qword ptr [rip + response_type_len], ct_html_end - ct_html
    ret
set_type_css:
    lea rax, [rip + ct_css]
    mov qword ptr [rip + response_type_ptr], rax
    mov qword ptr [rip + response_type_len], ct_css_end - ct_css
    ret
set_type_js:
    lea rax, [rip + ct_js]
    mov qword ptr [rip + response_type_ptr], rax
    mov qword ptr [rip + response_type_len], ct_js_end - ct_js
    ret
set_type_svg:
    lea rax, [rip + ct_svg]
    mov qword ptr [rip + response_type_ptr], rax
    mov qword ptr [rip + response_type_len], ct_svg_end - ct_svg
    ret

# send_all(socket, buf, len)
send_all:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov qword ptr [rbp - 8], rcx
    mov qword ptr [rbp - 16], rdx
    mov qword ptr [rbp - 24], r8

.send_loop:
    cmp qword ptr [rbp - 24], 0
    je .send_done
    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [rbp - 16]
    mov r8, qword ptr [rbp - 24]
    xor r9d, r9d
    call send
    cmp eax, 0
    jle .send_done
    cdqe
    add qword ptr [rbp - 16], rax
    sub qword ptr [rbp - 24], rax
    jmp .send_loop

.send_done:
    leave
    ret

# write_stdout(ptr, len)
write_stdout:
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
    lea r9, [rip + written_done]
    mov qword ptr [rsp + 32], 0
    call WriteFile

    leave
    ret

# die(ptr, len)
die:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    call write_stdout
    mov ecx, 1
    call ExitProcess

# u64_to_dec(value) -> rax=ptr, rdx=len
u64_to_dec:
    lea r11, [rip + len_buf_end]
    xor r9, r9
    mov rax, rcx
    test rax, rax
    jne .dec_loop
    dec r11
    mov byte ptr [r11], '0'
    mov rax, r11
    mov edx, 1
    ret

.dec_loop:
    mov r10, 10
.dec_step:
    xor rdx, rdx
    div r10
    dec r11
    add dl, '0'
    mov byte ptr [r11], dl
    inc r9
    test rax, rax
    jne .dec_step
    mov rax, r11
    mov rdx, r9
    ret
