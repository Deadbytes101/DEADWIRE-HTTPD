.intel_syntax noprefix

# DEADWIRE V2 HTTP engine lane entry.
# This is the topology-facing lane entry for the fixed triple-thread runtime.

.extern dw_runtime_work_step
.extern dw_runtime_worker_take
.extern dw_runtime_handle_client
.extern dw_runtime_worker_complete

.equ DW_ENTRY_WORKER_PTR, 8
.equ DW_ENTRY_LAST_RESULT, 32

.section .text
.global dw_runtime_http_engine_step
.global dw_runtime_http_request_step
.global dw_runtime_http_engine_entry
.global dw_runtime_http_request_entry

# dw_runtime_http_engine_step(worker rcx) maps the HTTP engine lane handoff step.
dw_runtime_http_engine_step:
    jmp dw_runtime_work_step

# dw_runtime_http_request_step(worker rcx) maps one HTTP request-processing step.
# It takes one queued client, handles the request, then completes the client.
dw_runtime_http_request_step:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    test rcx, rcx
    je .http_request_bad
    mov qword ptr [rbp - 8], rcx

    call dw_runtime_worker_take
    test rax, rax
    je .http_request_idle
    mov qword ptr [rbp - 16], rax

    mov rcx, rax
    call dw_runtime_handle_client
    test eax, eax
    jne .http_request_bad

    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [rbp - 16]
    call dw_runtime_worker_complete
    leave
    ret

.http_request_idle:
    mov eax, 1
    leave
    ret

.http_request_bad:
    mov eax, 1
    leave
    ret

# dw_runtime_http_engine_entry(entry_context rcx) maps the HTTP engine lane entry ABI.
dw_runtime_http_engine_entry:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    test rcx, rcx
    je .http_engine_bad_no_context
    mov qword ptr [rbp - 8], rcx
    mov rcx, qword ptr [rcx + DW_ENTRY_WORKER_PTR]
    test rcx, rcx
    je .http_engine_bad
    call dw_runtime_http_engine_step
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_ENTRY_LAST_RESULT], rax
    leave
    ret

.http_engine_bad:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_ENTRY_LAST_RESULT], rax
    leave
    ret

.http_engine_bad_no_context:
    mov eax, 1
    leave
    ret

# dw_runtime_http_request_entry(entry_context rcx) maps the request-processing entry ABI.
dw_runtime_http_request_entry:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    test rcx, rcx
    je .http_request_entry_bad_no_context
    mov qword ptr [rbp - 8], rcx
    mov rcx, qword ptr [rcx + DW_ENTRY_WORKER_PTR]
    test rcx, rcx
    je .http_request_entry_bad
    call dw_runtime_http_request_step
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_ENTRY_LAST_RESULT], rax
    leave
    ret

.http_request_entry_bad:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_ENTRY_LAST_RESULT], rax
    leave
    ret

.http_request_entry_bad_no_context:
    mov eax, 1
    leave
    ret
