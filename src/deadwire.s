.intel_syntax noprefix
.global _start

.equ SYS_READ,      0
.equ SYS_WRITE,     1
.equ SYS_CLOSE,     3
.equ SYS_LSEEK,     8
.equ SYS_SOCKET,    41
.equ SYS_ACCEPT,    43
.equ SYS_BIND,      49
.equ SYS_LISTEN,    50
.equ SYS_SETSOCKOPT,54
.equ SYS_EXIT,      60
.equ SYS_OPENAT,    257

.equ AF_INET,       2
.equ SOCK_STREAM,   1
.equ SOL_SOCKET,    1
.equ SO_REUSEADDR,  2
.equ AT_FDCWD,     -100
.equ O_RDONLY,      0
.equ SEEK_SET,      0
.equ SEEK_END,      2

.equ REQ_CAP,       4096
.equ PATH_CAP,      512
.equ FILE_CAP,      65536

.section .rodata
banner:
    .ascii "DEADWIRE HTTPD v0.3.0 ACCESS LOG\n"
    .ascii "linux x86-64 assembly / raw syscalls / no libc\n"
    .ascii "listening on http://127.0.0.1:18080\n"
banner_end:

fatal_socket: .ascii "fatal: socket failed\n"
fatal_socket_end:
fatal_bind:   .ascii "fatal: bind failed; is port 18080 already in use?\n"
fatal_bind_end:
fatal_listen: .ascii "fatal: listen failed\n"
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

log_200_static: .ascii "access 200 static\n"
log_200_static_end:
log_200_health: .ascii "access 200 /health\n"
log_200_health_end:
log_400: .ascii "access 400 bad-request\n"
log_400_end:
log_403: .ascii "access 403 forbidden\n"
log_403_end:
log_404: .ascii "access 404 not-found\n"
log_404_end:
log_405: .ascii "access 405 method\n"
log_405_end:
log_413: .ascii "access 413 too-large\n"
log_413_end:
log_414: .ascii "access 414 uri-too-long\n"
log_414_end:
log_500: .ascii "access 500 file-error\n"
log_500_end:

public_prefix: .ascii "public"
public_prefix_end:
index_path: .ascii "public/index.html\0"
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
server_fd: .quad 0
response_type_ptr: .quad 0
response_type_len: .quad 0
request_buf: .skip REQ_CAP
path_buf: .skip PATH_CAP
file_buf: .skip FILE_CAP
len_buf: .skip 32
len_buf_end:

.section .text
_start:
    mov rax, SYS_SOCKET
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    syscall
    test rax, rax
    js .die_socket
    mov qword ptr [rip + server_fd], rax

    mov rdi, rax
    mov rax, SYS_SETSOCKOPT
    mov rsi, SOL_SOCKET
    mov rdx, SO_REUSEADDR
    lea r10, [rip + reuse_one]
    mov r8, 4
    syscall

    mov rax, SYS_BIND
    mov rdi, qword ptr [rip + server_fd]
    lea rsi, [rip + sockaddr_in]
    mov rdx, sockaddr_in_end - sockaddr_in
    syscall
    test rax, rax
    js .die_bind

    mov rax, SYS_LISTEN
    mov rdi, qword ptr [rip + server_fd]
    mov rsi, 16
    syscall
    test rax, rax
    js .die_listen

    mov rdi, 1
    lea rsi, [rip + banner]
    mov rdx, banner_end - banner
    call write_all

.accept_loop:
    mov rax, SYS_ACCEPT
    mov rdi, qword ptr [rip + server_fd]
    xor rsi, rsi
    xor rdx, rdx
    syscall
    test rax, rax
    js .accept_loop

    mov rdi, rax
    call handle_client
    jmp .accept_loop

.die_socket:
    mov rdi, 2
    lea rsi, [rip + fatal_socket]
    mov rdx, fatal_socket_end - fatal_socket
    call write_all
    jmp .exit1
.die_bind:
    mov rdi, 2
    lea rsi, [rip + fatal_bind]
    mov rdx, fatal_bind_end - fatal_bind
    call write_all
    jmp .exit1
.die_listen:
    mov rdi, 2
    lea rsi, [rip + fatal_listen]
    mov rdx, fatal_listen_end - fatal_listen
    call write_all
.exit1:
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

# handle_client(client_fd)
handle_client:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    call set_type_text

    mov rax, SYS_READ
    mov rdi, r12
    lea rsi, [rip + request_buf]
    mov rdx, REQ_CAP
    syscall
    test rax, rax
    jle .close_client

    mov r13, rax                # request byte count

    cmp r13, 5
    jb .bad_request

    lea rsi, [rip + request_buf]
    cmp byte ptr [rsi + 0], 'G'
    jne .method_not_allowed
    cmp byte ptr [rsi + 1], 'E'
    jne .method_not_allowed
    cmp byte ptr [rsi + 2], 'T'
    jne .method_not_allowed
    cmp byte ptr [rsi + 3], ' '
    jne .method_not_allowed

    lea r14, [rip + request_buf + 4]   # path start
    mov r15, r13
    sub r15, 4                         # max bytes left after "GET "
    xor rbx, rbx                       # path length

    cmp byte ptr [r14], '/'
    jne .forbidden

.scan_path:
    cmp rbx, r15
    jae .bad_request                   # no delimiter before read buffer ended

    mov al, byte ptr [r14 + rbx]
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
    mov rcx, rbx
    inc rcx
    cmp rcx, r15
    jae .not_dot
    cmp byte ptr [r14 + rcx], '.'
    je .forbidden
.not_dot:
    inc rbx
    cmp rbx, 500
    ja .uri_too_long
    jmp .scan_path

.path_ready:
    test rbx, rbx
    jz .bad_request

    cmp rbx, 7
    jne .not_health
    lea rsi, [rip + health_path]
    mov rcx, 7
    mov rdi, r14
    repe cmpsb
    je .health
.not_health:
    cmp rbx, 1
    jne .build_public_path
    cmp byte ptr [r14], '/'
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

    mov rsi, r14
    mov rcx, rbx
    rep movsb
    mov byte ptr [rdi], 0

.serve_file:
    mov rax, SYS_OPENAT
    mov rdi, AT_FDCWD
    lea rsi, [rip + path_buf]
    mov rdx, O_RDONLY
    xor r10, r10
    syscall
    test rax, rax
    js .not_found

    mov r13, rax                       # file fd

    mov rax, SYS_LSEEK
    mov rdi, r13
    xor rsi, rsi
    mov rdx, SEEK_END
    syscall
    test rax, rax
    js .file_error
    cmp rax, FILE_CAP
    ja .file_too_large
    mov r15, rax                       # file size

    mov rax, SYS_LSEEK
    mov rdi, r13
    xor rsi, rsi
    mov rdx, SEEK_SET
    syscall
    test rax, rax
    js .file_error

    mov rax, SYS_READ
    mov rdi, r13
    lea rsi, [rip + file_buf]
    mov rdx, r15
    syscall
    test rax, rax
    js .file_error

    mov rbx, rax                       # bytes actually read

    mov rax, SYS_CLOSE
    mov rdi, r13
    syscall

    lea rdi, [rip + path_buf]
    call detect_content_type

    mov rdi, 1
    lea rsi, [rip + log_200_static]
    mov rdx, log_200_static_end - log_200_static
    call write_all

    mov rdi, r12
    lea rsi, [rip + status_200]
    mov rdx, status_200_end - status_200
    lea r8, [rip + file_buf]
    mov r9, rbx
    call send_response
    jmp .close_client

.health:
    mov rdi, 1
    lea rsi, [rip + log_200_health]
    mov rdx, log_200_health_end - log_200_health
    call write_all
    mov rdi, r12
    lea rsi, [rip + status_200]
    mov rdx, status_200_end - status_200
    lea r8, [rip + body_health]
    mov r9, body_health_end - body_health
    call send_response
    jmp .close_client

.bad_request:
    mov rdi, 1
    lea rsi, [rip + log_400]
    mov rdx, log_400_end - log_400
    call write_all
    mov rdi, r12
    lea rsi, [rip + status_400]
    mov rdx, status_400_end - status_400
    lea r8, [rip + body_400]
    mov r9, body_400_end - body_400
    call send_response
    jmp .close_client
.forbidden:
    mov rdi, 1
    lea rsi, [rip + log_403]
    mov rdx, log_403_end - log_403
    call write_all
    mov rdi, r12
    lea rsi, [rip + status_403]
    mov rdx, status_403_end - status_403
    lea r8, [rip + body_403]
    mov r9, body_403_end - body_403
    call send_response
    jmp .close_client
.not_found:
    mov rdi, 1
    lea rsi, [rip + log_404]
    mov rdx, log_404_end - log_404
    call write_all
    mov rdi, r12
    lea rsi, [rip + status_404]
    mov rdx, status_404_end - status_404
    lea r8, [rip + body_404]
    mov r9, body_404_end - body_404
    call send_response
    jmp .close_client
.method_not_allowed:
    mov rdi, 1
    lea rsi, [rip + log_405]
    mov rdx, log_405_end - log_405
    call write_all
    mov rdi, r12
    lea rsi, [rip + status_405]
    mov rdx, status_405_end - status_405
    lea r8, [rip + body_405]
    mov r9, body_405_end - body_405
    call send_response
    jmp .close_client
.file_too_large:
    mov rax, SYS_CLOSE
    mov rdi, r13
    syscall
    mov rdi, 1
    lea rsi, [rip + log_413]
    mov rdx, log_413_end - log_413
    call write_all
    mov rdi, r12
    lea rsi, [rip + status_413]
    mov rdx, status_413_end - status_413
    lea r8, [rip + body_413]
    mov r9, body_413_end - body_413
    call send_response
    jmp .close_client
.uri_too_long:
    mov rdi, 1
    lea rsi, [rip + log_414]
    mov rdx, log_414_end - log_414
    call write_all
    mov rdi, r12
    lea rsi, [rip + status_414]
    mov rdx, status_414_end - status_414
    lea r8, [rip + body_414]
    mov r9, body_414_end - body_414
    call send_response
    jmp .close_client
.file_error:
    mov rax, SYS_CLOSE
    mov rdi, r13
    syscall
    mov rdi, 1
    lea rsi, [rip + log_500]
    mov rdx, log_500_end - log_500
    call write_all
    mov rdi, r12
    lea rsi, [rip + status_500]
    mov rdx, status_500_end - status_500
    lea r8, [rip + body_500]
    mov r9, body_500_end - body_500
    call send_response

.close_client:
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# send_response(fd, status_ptr, status_len, body_ptr, body_len)
send_response:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15, r8
    mov rbx, r9

    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call write_all

    mov rdi, r12
    lea rsi, [rip + header_type_prefix]
    mov rdx, header_type_prefix_end - header_type_prefix
    call write_all

    mov rdi, r12
    mov rsi, qword ptr [rip + response_type_ptr]
    mov rdx, qword ptr [rip + response_type_len]
    call write_all

    mov rdi, r12
    lea rsi, [rip + header_len_prefix]
    mov rdx, header_len_prefix_end - header_len_prefix
    call write_all

    mov rax, rbx
    call u64_to_dec                    # returns rsi ptr, rdx len
    mov rdi, r12
    call write_all

    mov rdi, r12
    lea rsi, [rip + header_end]
    mov rdx, header_end_end - header_end
    call write_all

    mov rdi, r12
    mov rsi, r15
    mov rdx, rbx
    call write_all

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# detect_content_type(path_ptr)
detect_content_type:
    push rbx
    push rcx
    push rdx

    call set_type_text
    mov rbx, rdi
    xor rcx, rcx
.len_loop:
    cmp rcx, PATH_CAP
    jae .done
    cmp byte ptr [rbx + rcx], 0
    je .len_done
    inc rcx
    jmp .len_loop
.len_done:
    cmp rcx, 5
    jb .check_4
    lea rdx, [rbx + rcx - 5]
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
    cmp rcx, 4
    jb .check_3
    lea rdx, [rbx + rcx - 4]
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
    cmp rcx, 3
    jb .done
    lea rdx, [rbx + rcx - 3]
    cmp byte ptr [rdx + 0], '.'
    jne .done
    cmp byte ptr [rdx + 1], 'j'
    jne .done
    cmp byte ptr [rdx + 2], 's'
    jne .done
    call set_type_js
.done:
    pop rdx
    pop rcx
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

# write_all(fd, buf, len)
write_all:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi
    mov rbx, rdx

.write_loop:
    test rbx, rbx
    jz .write_done
    mov rax, SYS_WRITE
    mov rdi, r12
    mov rsi, r13
    mov rdx, rbx
    syscall
    test rax, rax
    jle .write_done
    add r13, rax
    sub rbx, rax
    jmp .write_loop

.write_done:
    pop r13
    pop r12
    pop rbx
    ret

# u64_to_dec(rax) -> rsi=ptr, rdx=len
u64_to_dec:
    push rbx
    mov rbx, 10
    lea rsi, [rip + len_buf_end]
    xor rcx, rcx
    test rax, rax
    jne .dec_loop
    dec rsi
    mov byte ptr [rsi], '0'
    mov rdx, 1
    pop rbx
    ret

.dec_loop:
    xor rdx, rdx
    div rbx
    dec rsi
    add dl, '0'
    mov byte ptr [rsi], dl
    inc rcx
    test rax, rax
    jne .dec_loop
    mov rdx, rcx
    pop rbx
    ret
