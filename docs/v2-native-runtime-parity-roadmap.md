# V2 NATIVE RUNTIME PARITY ROADMAP

DEADWIRE HTTPD V1.3.0 is released. The default server path is still the small blocking HTTP/1.0 server.

V2 is the opt-in native runtime track. It does not get to claim victory because a file exists. It earns the claim by running, failing loudly, and staying measurable.

## Truth

```txt
DEFAULT PRODUCT STATE:
- close-after-response server remains the default path
- Windows x86-64 assembly path still owns the default server
- Linux and macOS paths remain explicit platform backends
- keep-alive remains opt-in and sequential
```

```txt
CURRENT V2 PROOF:
- fixed triple-thread runtime shape: supervisor / acceptor / HTTP engine
- no worker pool
- no thread-per-connection design
- V2 request step takes one queued client, runs the HTTP handler, and completes it
- V2 tick path accepts a loopback client and routes through the request step
- deadwire_v2_runtime.exe runs a live smoke path and exits nonzero on failure
- make verify-triple-thread reaches verify-v2final and executes the V2 runtime exe
```

```txt
NOT YET TRUE:
- default server does not run on the V2 runtime yet
- no long-running V2 listener mode yet
- no multicore scaling claim
- no public internet hardening claim
- no TLS, CGI, async, or framework layer
```

## Target

```txt
TARGET STATE:
- assembly-first product core
- fixed triple-thread runtime
- custom native thread abstraction
- custom synchronization primitive layer
- acceptor owns socket intake
- HTTP engine owns request parsing and response
- connection lifecycle owned by DEADWIRE runtime
- deterministic local benchmark harness
- claims backed by tests and measurements
```

No cosplay. No borrowed glory. The machine either does it or it does not.

## Architecture Target

```mermaid
flowchart LR
    MAIN["MAIN ENTRY"] --> SUP["SUPERVISOR"]
    SUP --> INIT["RUNTIME INIT"]
    INIT --> ACC["ACCEPTOR LANE"]
    INIT --> HTTP["HTTP ENGINE LANE"]
    ACC --> ACCEPT["ACCEPT CLIENT"]
    ACCEPT --> HANDOFF["FIXED HANDOFF / QUEUE"]
    HANDOFF --> HTTP
    HTTP --> RECV["RECV REQUEST"]
    RECV --> PARSE["REQUEST PARSER"]
    PARSE --> GUARD["PATH GUARD"]
    GUARD --> ROUTE["ROUTE"]
    ROUTE --> RESPONSE["RESPONSE BUILDER"]
    RESPONSE --> SEND["SEND ALL"]
    SEND --> CLOSE["CLOSE OR EXPLICIT POLICY"]
```

## Milestones

### V2.0: Runtime Boundary

```txt
- split server runtime from platform backend
- define assembly-call ABI for runtime functions
- isolate startup, socket, request, file, response, and shutdown boundaries
- keep default server behavior unchanged
```

Pass condition:

```txt
make verify
make verify-runtime-boundary
```

Status:

```txt
DONE ENOUGH TO MOVE FORWARD.
```

### V2.1: Fixed Runtime Topology

```txt
- supervisor owns lifetime
- acceptor lane owns intake
- HTTP engine lane owns request work
- no output lane as a fourth runtime thread
- no worker pool
- no thread-per-connection design
```

Pass condition:

```txt
make verify-triple-thread
```

Status:

```txt
ACTIVE AND ENFORCED BY SHAPE PROBES.
```

### V2.2: Request Step

```txt
- queued client enters HTTP request step
- request step calls the runtime HTTP handler
- completed client exits through output queue
- live loopback request probe checks HTTP 200 and body
```

Pass condition:

```txt
make verify-triple-thread
```

Status:

```txt
ACTIVE AND CHAINED INTO VERIFY.
```

### V2.3: Executable Live Smoke

```txt
- build/deadwire_v2_runtime.exe opens a loopback listener
- local peer sends one GET request
- bounded V2 mode processes the request
- response status and body are checked
- sockets close cleanly
- process exits nonzero on failure
```

Pass condition:

```txt
make build-v2-runtime
.\build\deadwire_v2_runtime.exe
make verify-triple-thread
```

Status:

```txt
ACTIVE. VERIFY-V2FINAL RUNS THE EXE.
```

### V2.4: Long-Running V2 Mode

```txt
- opt-in executable can run a bounded listener loop
- shutdown path is explicit
- errors have stable exit codes
- default server still untouched until parity is proven
```

Pass condition:

```txt
local smoke passes
bounded multi-request test passes
no leaked socket handle in local probe
```

### V2.5: Default Server Parity Gate

```txt
- V2 path preserves V1 behavior for /health, /, /hello.txt, /style.css, missing files, method rejection, and path guard
- close-after-response remains default
- keep-alive stays explicit
- benchmark proves scaling or the claim is not made
```

Pass condition:

```txt
make verify
make verify-triple-thread
V1/V2 parity probes pass
release notes do not overclaim
```

## Non-Goals

```txt
- no TLS in this track
- no CGI in this track
- no async framework
- no third-party HTTP parser
- no public internet hardening claim
- no fake benchmark marketing
```

## Engineering Rules

```txt
TRUTH FIRST.
EVERY CLAIM NEEDS A TEST OR BENCH.
DEFAULT PATH MUST STAY SAFE.
NO FEATURE THAT HIDES THE MACHINE.
NO RUNTIME MAGIC THAT CANNOT BE EXPLAINED AT THE ABI LEVEL.
```

## Immediate Next Step

```txt
NEXT PATCH:
- document the current V2 executable proof
- keep default server wording honest
- do not claim public server performance from the local V2 microbench
```
