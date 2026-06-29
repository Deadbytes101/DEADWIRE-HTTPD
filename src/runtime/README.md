# DEADWIRE RUNTIME CORE

This directory defines the product runtime boundary for V2 work.

V2 is assembly-first. This directory is not a C glue layer and must not become one.

## Current implementation

The current Windows implementation still lives in `src/deadwire_windows.s`. V2.0 maps that monolithic assembly file into runtime roles before moving code.

```txt
runtime entry          -> mainCRTStartup
runtime accept loop    -> .accept_loop
runtime client handler -> handle_client
runtime response path  -> send_response
runtime send-all path  -> send_all
runtime type detector  -> detect_content_type
runtime fatal path     -> die
```

## Runtime owns

```txt
REQUEST LIFECYCLE
REQUEST PARSE POLICY
PATH GUARD POLICY
RESPONSE SHAPE
CONNECTION CLOSE POLICY
SEND-ALL GUARANTEE
KEEP-ALIVE POLICY HOOKS
```

## Runtime does not own

```txt
WINSOCK STARTUP
SOCKET CREATION
BIND/LISTEN/ACCEPT SYSCALL OR API DETAILS
PLATFORM FILE OPEN/READ/CLOSE DETAILS
CONSOLE HANDLE DETAILS
BUILD SCRIPT PATCHING
BENCHMARK TOOLING
```

## Rule

```txt
NO BEHAVIOR CHANGE WHILE SPLITTING THE BOUNDARY.
NO THREADS UNTIL THE RUNTIME ENTRY AND CONNECTION LIFECYCLE ARE STABLE.
NO CONCURRENCY CLAIM UNTIL TESTS AND BENCHMARKS PROVE IT.
```
