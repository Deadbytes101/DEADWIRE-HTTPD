# V2 RUNTIME BOUNDARY CONTRACT

This is the first V2 step. It does not add threads yet. It freezes the boundary that future thread, mutex, queue, and worker-pool work must respect.

## Rule

```txt
NO BEHAVIOR CHANGE IN V2.0.
SPLIT THE MACHINE IN YOUR HEAD BEFORE SPLITTING THE FILES.
EVERY BOUNDARY MUST BE TESTABLE.
```

## Current Runtime Shape

```txt
mainCRTStartup
  -> platform startup
  -> socket setup
  -> bind/listen
  -> accept loop
  -> handle_client
  -> request parser
  -> path guard
  -> static file or /health
  -> response builder
  -> send_all
  -> close socket
```

## Product/Core Boundary

Product runtime means code that ships as the server behavior.

```txt
SERVER ENTRY
REQUEST LIFECYCLE
PARSER
PATH GUARD
RESPONSE BUILDER
CONNECTION LIFECYCLE
SEND-ALL GUARANTEE
```

Tooling is not product runtime.

```txt
BENCHMARK TOOLS
BUILD SCRIPTS
VERIFY SCRIPTS
RELEASE NOTES
DOCS
```

C is allowed for benchmark tooling. C is not allowed as server-runtime glue in the V2 target.

## V2.0 ABI Intent

The first runtime split must preserve this call shape:

```txt
runtime_main(platform_backend*)
runtime_accept_loop(platform_backend*)
runtime_handle_client(connection*)
runtime_send_response(connection*, response*)
runtime_send_all(connection*, buffer, length)
```

The implementation may stay in assembly labels at first. The point of V2.0 is to make the boundary explicit and verifiable before V2.1 starts thread work.

## Required Windows Assembly Labels

```txt
mainCRTStartup
.accept_loop
handle_client
send_response
send_all
detect_content_type
write_stdout
die
```

## Required Platform Imports

```txt
WSAStartup
WSACleanup
socket
setsockopt
bind
listen
accept
recv
send
closesocket
CreateFileA
ReadFile
GetFileSizeEx
CloseHandle
ExitProcess
```

## V2.0 Pass Condition

```powershell
make verify
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-runtime-boundary.ps1
```

`verify-runtime-boundary.ps1` is an architecture guard. It proves that the current single-threaded implementation still exposes the labels and calls that future V2 runtime work must split without changing behavior.

A later patch may wire this into `make verify-runtime-boundary` after the Makefile target layout is cleaned up.

## Not Yet

```txt
NO THREADS YET
NO MUTEX YET
NO FUTEX CLAIM YET
NO WORKER POOL YET
NO CONCURRENCY CLAIM YET
```

Threads start only after the boundary is stable.
