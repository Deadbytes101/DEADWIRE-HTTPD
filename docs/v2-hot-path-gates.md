# V2 Hot Path Gates

DEADWIRE V2 keeps the runtime topology small and makes hot-path overhead visible.

The generated V2 runtime is checked at multiple levels:

- source shape: `scripts/verify-v2hotshape.ps1`
- object shape: `scripts/verify-v2hotobject.ps1`
- executable shape: `scripts/verify-v2hotexe.ps1`
- instruction budget: `scripts/verify-v2budget.ps1`
- byte-size budget: `scripts/verify-v2size.ps1`
- call-count budget: `scripts/verify-v2callbudget.ps1`
- branch-count budget: `scripts/verify-v2branchbudget.ps1`
- live smoke executable: `build/deadwire_v2_runtime.exe`

These gates are chained from `scripts/verify-v2final.ps1`, which is reached by `make verify-triple-thread`.

## Current hot helpers

| helper | instructions | bytes | calls | branches |
| --- | ---: | ---: | ---: | ---: |
| `dw_runtime_accept_enqueue` | 1/1 | 5/5 | 0/0 | 1/1 |
| `dw_runtime_output_drain` | 1/1 | 5/5 | 0/0 | 1/1 |
| `dw_runtime_worker_take` | 22/24 | 66/72 | 0/0 | 6/6 |
| `dw_runtime_worker_complete` | 18/20 | 51/56 | 0/0 | 5/5 |
| `dw_runtime_work_step` | 8/10 | 24/28 | 2/2 | 2/2 |

## Microbench

Run the V2 handoff microbench:

```powershell
make bench-v2-runtime
```

The benchmark exercises the generated hot runtime handoff path: input queue push, HTTP engine step, and output queue drain. It prints requests, seconds, ns/op, and ops/s for each round, then prints a median ns/op summary. Timing is informational; structural budgets remain enforced by the verify gates.

This is not a public server benchmark. It is a local runtime handoff measurement.

## Live smoke

`make verify-triple-thread` reaches `verify-v2final`, builds `deadwire_v2_runtime.exe`, checks the hot helpers, then runs the executable.

That executable opens loopback through a V2 long-mode controller, runs a bounded health loop, sends four `/health` method requests one by one, runs bounded V2 mode for each request, checks each HTTP 200 response shape against V1 health behavior, proves the queue cursor wraps back to zero, closes sockets, and exits nonzero on failure.

The health parity probe checks the narrow V1 `/health` response shape only. It is not a full V1/V2 parity claim.

The method parity probe checks both the normal payload path and the empty-payload path.

The bounded loop proof tracks target count, completed count, and last result.

The long-mode proof tracks target count, completed count, stop reason, last result, and shutdown result.

The shutdown proof checks that the live socket is reset, the live close result is zero, the accepted client socket returns to the sentinel value, and a second live close remains clean.

## Rule

If a hot helper grows, it must be intentional. The verifier should fail first, then the budget can be raised with a reason.

No silent overhead drift.
