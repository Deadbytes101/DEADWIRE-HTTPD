.intel_syntax noprefix

# DEADWIRE V2 handle source.
# This is assembled only by V2 opt-in build and verifier paths for now.
# It is not linked into the default server build.

.extern WaitForSingleObject
.extern CloseHandle

.equ DW_WAIT_FOREVER, 0xffffffff

.section .text
.global dw_runtime_wait_handle
.global dw_runtime_close_handle

# dw_runtime_wait_handle(handle rcx) waits for one handle.
dw_runtime_wait_handle:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    test rcx, rcx
    je .wait_bad
    mov edx, DW_WAIT_FOREVER
    call WaitForSingleObject
    leave
    ret

.wait_bad:
    mov eax, 1
    leave
    ret

# dw_runtime_close_handle(handle rcx) closes one handle.
dw_runtime_close_handle:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    test rcx, rcx
    je .close_bad
    call CloseHandle
    leave
    ret

.close_bad:
    xor eax, eax
    leave
    ret
