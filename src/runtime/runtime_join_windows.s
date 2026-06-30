.intel_syntax noprefix

# DEADWIRE V2 lane join source.
# This is assembled only by V2 opt-in build and verifier paths for now.
# It is not linked into the default server build.

.extern dw_runtime_wait_handle
.extern dw_runtime_close_handle

.equ DW_SPAWN_ACCEPT_HANDLE, 48
.equ DW_SPAWN_WORK_HANDLE, 56
.equ DW_SPAWN_OUTPUT_HANDLE, 64
.equ DW_SPAWN_LAST_RESULT, 72

.section .text
.global dw_runtime_join_lanes

# dw_runtime_join_lanes(spawn_context rcx) joins the accept and HTTP lane handles.
dw_runtime_join_lanes:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    test rcx, rcx
    je .join_bad_no_context
    mov qword ptr [rbp - 8], rcx

    mov r10, qword ptr [rbp - 8]
    mov rcx, qword ptr [r10 + DW_SPAWN_ACCEPT_HANDLE]
    test rcx, rcx
    je .join_bad
    call dw_runtime_wait_handle
    test eax, eax
    jne .join_bad

    mov r10, qword ptr [rbp - 8]
    mov rcx, qword ptr [r10 + DW_SPAWN_WORK_HANDLE]
    test rcx, rcx
    je .join_bad
    call dw_runtime_wait_handle
    test eax, eax
    jne .join_bad

    mov r10, qword ptr [rbp - 8]
    mov rcx, qword ptr [r10 + DW_SPAWN_ACCEPT_HANDLE]
    call dw_runtime_close_handle
    test eax, eax
    je .join_bad

    mov r10, qword ptr [rbp - 8]
    mov rcx, qword ptr [r10 + DW_SPAWN_WORK_HANDLE]
    call dw_runtime_close_handle
    test eax, eax
    je .join_bad

    xor eax, eax
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_SPAWN_OUTPUT_HANDLE], rax
    mov qword ptr [r10 + DW_SPAWN_LAST_RESULT], rax
    leave
    ret

.join_bad:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_SPAWN_LAST_RESULT], rax
    leave
    ret

.join_bad_no_context:
    mov eax, 1
    leave
    ret
