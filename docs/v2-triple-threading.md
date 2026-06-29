# DEADWIRE V2 Triple-threading Architecture

Triple-threading is the DEADWIRE V2 runtime name for a three-lane server architecture. It is not a claim that three threads are magically faster than ordinary multi-threading. It is a strict runtime shape that keeps accept, request work, and response output separated so each lane can be measured and optimized independently.

This document is a design gate. It does not change the default server build.

## Intent

Build a runtime that can compete on measurable behavior instead of slogans:

- predictable client lifecycle
- explicit request boundary
- bounded handoff points
- measurable queue depth
- measurable worker throughput
- no hidden default behavior change

## Runtime lanes

### Lane 1: Accept lane

The accept lane owns listening socket progression and client context creation.

Responsibilities:

- accept new connections
- allocate or reuse a client context
- assign socket, receive buffer, receive capacity, and response pointer
- hand the context to the work lane

It must not parse requests and must not generate responses.

### Lane 2: Work lane

The work lane owns request lifecycle execution.

Responsibilities:

- call `dw_runtime_recv_request`
- call request parser boundaries such as `dw_runtime_request_is_get`
- choose the response object
- return a completed client context to the output lane

It must not accept new sockets.

### Lane 3: Output lane

The output lane owns deterministic response writing and close policy.

Responsibilities:

- call `dw_runtime_send_response`
- use `dw_runtime_send_all` for complete writes
- close or recycle client context according to the selected runtime mode

It must not accept sockets and must not parse requests.

## Current V2 foundation

The current V2 runtime object already has executable-tested pieces that fit the three-lane shape:

```txt
dw_runtime_recv_request      -> request input boundary
dw_runtime_request_is_get    -> parser boundary
dw_runtime_handle_client     -> early client lifecycle anchor
dw_runtime_send_response     -> response writer boundary
dw_runtime_send_all          -> write completion loop
dw_runtime_u64_to_dec        -> content-length helper
```

## Error contract

The current handle-client path uses explicit return codes:

```txt
0 = ok
1 = null client context
2 = missing response pointer
3 = receive failed or closed
4 = request rejected by parser boundary
```

These return codes must remain testable before any worker pool is wired in.

## Implementation order

Triple-threading must be built in this order:

```txt
1. Keep V2 runtime object executable-tested.
2. Add queue data layout and symbol anchors.
3. Add queue push/pop executable harnesses.
4. Add worker context layout.
5. Add accept/work/output lane boundary symbols.
6. Add thread creation only after queue and lifecycle gates pass.
7. Add benchmark gates only after runtime behavior is stable.
```

Thread creation before queue verification is forbidden. A worker pool without a proven handoff contract is not a runtime architecture.

## Competitive claim rule

DEADWIRE may only claim a performance win after benchmark evidence exists for the same scenario against the comparison target.

Allowed current claim:

```txt
DEADWIRE V2 has an executable-tested runtime lifecycle foundation.
```

Forbidden current claim:

```txt
DEADWIRE V2 beats concurrent servers.
```

Future win criteria:

```txt
single connection latency
keep-alive throughput
concurrent connection throughput
error-rate under load
memory footprint under load
CPU usage under load
repeatable benchmark script
```

## Non-goals for this design gate

```txt
No default server behavior change.
No benchmark claim yet.
No thread pool yet.
No hidden rewrite of the V1 server path.
```

## Engineering rule

Triple-threading is a runtime contract first and a marketing term second. If the contract is not measured, the name means nothing.
