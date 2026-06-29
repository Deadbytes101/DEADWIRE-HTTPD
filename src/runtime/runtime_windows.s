.intel_syntax noprefix

# DEADWIRE V2 runtime source map.
# This file is assembled by scripts/verify-runtime-source-map.ps1.
# It is not linked into the default server build yet.
# The live implementation remains src/deadwire_windows.s.

.extern send

.global dw_runtime_main
.global dw_runtime_accept_loop
.global dw_runtime_handle_client
.global dw_runtime_send_response
.global dw_runtime_send_all
.global dw_runtime_write_output

# dw_runtime_main maps to mainCRTStartup.
dw_runtime_main:
    ret

# dw_runtime_accept_loop maps to .accept_loop.
dw_runtime_accept_loop:
    ret

# dw_runtime_handle_client maps to handle_client.
dw_runtime_handle_client:
    ret

# dw_runtime_send_response maps to send_response.
dw_runtime_send_response:
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

# dw_runtime_write_output maps to write_stdout.
dw_runtime_write_output:
    ret
