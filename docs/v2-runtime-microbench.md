# V2 Runtime Microbench

This document records the first DEADWIRE V2 runtime handoff microbench result.

The benchmark path is:

```txt
input queue push -> HTTP engine step -> output queue drain
```

This is a local runtime microbench, not an external HTTP server benchmark.

## Command

Preferred command:

```powershell
make bench-v2-runtime
```

Direct script command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/bench-v2-runtime.ps1 -Requests 262144 -Rounds 5
```

## Baseline

```txt
round 1: 4.40 ns/op
round 2: 8.37 ns/op
round 3: 4.64 ns/op
round 4: 4.26 ns/op
round 5: 4.70 ns/op
median:  4.64 ns/op
```

## Rule

Use this as a regression baseline for the same machine and toolchain only.
