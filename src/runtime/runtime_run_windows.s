.intel_syntax noprefix

# DEADWIRE V2 run source.
# This is assembled only by V2 opt-in build and verifier paths for now.
# It is not linked into the default server build.

.extern dw_runtime_spawn_lanes
.extern dw_runtime_join_lanes

.equ DW_SPAWN_LAST_RESULT, 72

.section .text
.global dw_runtime_run_lanes

# dw_runtime_run_lanes(spawn_context rcx) starts the lanes, then joins them.
dw_runtime_run_lanes:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    test rcx, rcx
    je .run_bad_no_context
    mov qword ptr [rbp - 8], rcx

    call dw_runtime_spawn_lanes
    test eax, eax
    jne .run_bad

    mov rcx, qword ptr [rbp - 8]
    call dw_runtime_join_lanes
    test eax, eax
    jne .run_bad

    xor eax, eax
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_SPAWN_LAST_RESULT], rax
    leave
    ret

.run_bad:
    mov eax, 1
    mov r10, qword ptr [rbp - 8]
    mov qword ptr [r10 + DW_SPAWN_LAST_RESULT], rax
    leave
    ret

.run_bad_no_context:
    mov eax, 1
    leave
    ret
