# V2 RUNTIME BOUNDARY

DEADWIRE V2 starts with a runtime boundary. HTTP behavior must remain compatible with the V1.3 default server while the V2 runtime stays behind explicit opt-in targets.

## Execution Lanes

```txt
lane 0: supervisor      process entry and runtime state
lane 1: acceptor        listen socket and accepted descriptor handoff
lane 2: http_engine     request lifecycle and response emission
```

The supervisor is the process entry lane. The V2 Windows opt-in runtime starts the acceptor and HTTP engine lanes through the platform thread API. That gives three execution lanes total, not a generic worker pool and not a thread-per-connection server.

## Product Boundary

```txt
default binary: build/deadwire.exe
scope:         V1.3 static-file server behavior
thread model:  blocking single-threaded default path
status:        release behavior must remain unchanged
```

## V2 Opt-In Boundary

```txt
opt-in binary: build/deadwire_v2_runtime.exe
make target:   make build-v2-runtime
verify target: make verify-runtime-boundary
               make verify-triple-thread
status:        experimental runtime lane proof
```

## Required Runtime Anchors

```txt
dw_runtime_main
dw_runtime_accept_loop
dw_runtime_handle_client
dw_runtime_recv_request
dw_runtime_request_is_get
dw_runtime_queue_push
dw_runtime_queue_pop
dw_runtime_worker_init
dw_runtime_worker_take
dw_runtime_worker_complete
dw_runtime_accept_enqueue
dw_runtime_work_step
dw_runtime_output_drain
dw_runtime_accept_entry
dw_runtime_work_entry
dw_runtime_send_response
dw_runtime_send_all
dw_runtime_write_output
dw_runtime_u64_to_dec
```

`dw_runtime_output_drain` may remain as an internal drain helper. It must not define an additional runtime lane in the fixed triple-thread target.

## Spawn Boundary

The fixed triple-thread target has exactly two platform thread spawn sites:

```txt
spawn acceptor lane
spawn HTTP engine lane
```

The supervisor lane is the process entry lane. A third spawned platform thread would turn the target into a four-lane runtime and must fail `verify-triple-thread`.

## Join Boundary

The join path waits for and closes only the two spawned lane handles:

```txt
acceptor handle
http_engine handle
```

A join dependency on a third spawned lane handle must fail `verify-triple-thread`.

## Proof Rule

```txt
make verify-runtime-boundary
make verify-triple-thread
```
