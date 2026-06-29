# V2 LOCAL VERIFY GATE

V2 work must pass both the architecture guard and the existing server behavior guard.

## Command

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2.ps1
```

## What it runs

```txt
scripts/verify-runtime-boundary.ps1
make verify
```

## Meaning

```txt
verify-runtime-boundary.ps1 = architecture and ownership guard
make verify = existing server behavior guard
```

## Rule

```txt
NO V2 PATCH IS CLEAN UNLESS VERIFY-V2 PASSES LOCALLY.
NO THREADS UNTIL VERIFY-V2 IS STABLE ACROSS BOUNDARY SPLITS.
NO CLAIMS WITHOUT TESTS.
```
