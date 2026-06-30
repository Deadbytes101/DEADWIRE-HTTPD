.intel_syntax noprefix

# DEADWIRE V2 HTTP engine lane entry alias.
# The implementation is still the existing work-lane step, but V2 now
# exposes the topology name used by the fixed triple-thread runtime.

.extern dw_runtime_work_entry

.section .text
.global dw_runtime_http_engine_entry

dw_runtime_http_engine_entry:
    jmp dw_runtime_work_entry
