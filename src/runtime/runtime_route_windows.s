.intel_syntax noprefix

.equ DW_ROUTE_HEALTH, 1
.equ DW_ROUTE_ROOT, 2
.equ DW_ROUTE_CSS, 3
.equ DW_ROUTE_MISSING, 4

.section .rdata
.dw_route_health_path:
    .ascii "/health"
.dw_route_health_path_end:
.dw_route_root_path:
    .ascii "/"
.dw_route_root_path_end:
.dw_route_css_path:
    .ascii "/style.css"
.dw_route_css_path_end:

.section .text
.global dw_runtime_request_path_is
.global dw_runtime_select_route

# dw_runtime_request_path_is(request rcx, length rdx, path r8, path_length r9) maps to a narrow V2 route match boundary.
dw_runtime_request_path_is:
    test rcx, rcx
    je .dw_runtime_request_path_is_no
    test r8, r8
    je .dw_runtime_request_path_is_no
    test rdx, rdx
    jle .dw_runtime_request_path_is_no
    test r9, r9
    jle .dw_runtime_request_path_is_no

    xor r10, r10
.dw_runtime_request_path_find_space:
    cmp r10, rdx
    jae .dw_runtime_request_path_is_no
    cmp byte ptr [rcx + r10], ' '
    je .dw_runtime_request_path_found_space
    inc r10
    jmp .dw_runtime_request_path_find_space

.dw_runtime_request_path_found_space:
    inc r10
    mov r11, r10
    add r11, r9
    cmp r11, rdx
    jae .dw_runtime_request_path_is_no

    xor r11, r11
.dw_runtime_request_path_compare:
    cmp r11, r9
    jae .dw_runtime_request_path_compare_done
    mov rax, r10
    add rax, r11
    movzx eax, byte ptr [rcx + rax]
    cmp al, byte ptr [r8 + r11]
    jne .dw_runtime_request_path_is_no
    inc r11
    jmp .dw_runtime_request_path_compare

.dw_runtime_request_path_compare_done:
    add r10, r9
    cmp byte ptr [rcx + r10], ' '
    jne .dw_runtime_request_path_is_no
    mov eax, 1
    ret

.dw_runtime_request_path_is_no:
    xor eax, eax
    ret

# dw_runtime_select_route(request rcx, length rdx) returns a narrow V2 route id.
dw_runtime_select_route:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    movsxd rdx, edx
    mov qword ptr [rbp - 8], rcx
    mov qword ptr [rbp - 16], rdx

    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [rbp - 16]
    lea r8, [rip + .dw_route_health_path]
    mov r9, .dw_route_health_path_end - .dw_route_health_path
    call dw_runtime_request_path_is
    test eax, eax
    jne .dw_runtime_select_route_health

    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [rbp - 16]
    lea r8, [rip + .dw_route_root_path]
    mov r9, .dw_route_root_path_end - .dw_route_root_path
    call dw_runtime_request_path_is
    test eax, eax
    jne .dw_runtime_select_route_root

    mov rcx, qword ptr [rbp - 8]
    mov rdx, qword ptr [rbp - 16]
    lea r8, [rip + .dw_route_css_path]
    mov r9, .dw_route_css_path_end - .dw_route_css_path
    call dw_runtime_request_path_is
    test eax, eax
    jne .dw_runtime_select_route_css

    mov eax, DW_ROUTE_MISSING
    leave
    ret

.dw_runtime_select_route_health:
    mov eax, DW_ROUTE_HEALTH
    leave
    ret

.dw_runtime_select_route_root:
    mov eax, DW_ROUTE_ROOT
    leave
    ret

.dw_runtime_select_route_css:
    mov eax, DW_ROUTE_CSS
    leave
    ret
