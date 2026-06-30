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

These gates are chained from `scripts/verify-v2final.ps1`, which is reached by `make verify-triple-thread`.

## Current hot helpers

| helper | instructions | bytes | calls | branches |
| --- | ---: | ---: | ---: | ---: |
| `dw_runtime_accept_enqueue` | 1/1 | 5/5 | 0/0 | 1/1 |
| `dw_runtime_output_drain` | 1/1 | 5/5 | 0/0 | 1/1 |
| `dw_runtime_worker_take` | 22/24 | 66/72 | 0/0 | 6/6 |
| `dw_runtime_worker_complete` | 18/20 | 51/56 | 0/0 | 5/5 |
| `dw_runtime_work_step` | 8/10 | 24/28 | 2/2 | 2/2 |

## Rule

If a hot helper grows, it must be intentional. The verifier should fail first, then the budget can be raised with a reason.

No silent overhead drift.
