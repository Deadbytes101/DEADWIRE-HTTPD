.intel_syntax noprefix

# DEADWIRE V2 runtime source map.
# This file is assembled by scripts/verify-runtime-source-map.ps1.
# It is not linked into the default server build yet.
# The live implementation remains src/deadwire_windows.s.

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

# dw_runtime_send_all maps to send_all.
dw_runtime_send_all:
    ret

# dw_runtime_write_output maps to write_stdout.
dw_runtime_write_output:
    ret
