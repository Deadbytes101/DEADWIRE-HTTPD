# WSL benchmark result: DEADWIRE Linux vs nihserver patched-section

This result is a labeled compatibility experiment. It is not an upstream nihserver result.

```text
benchmark: DEADWIRE Linux vs nihserver patched-section
host: WSL
mode: close
path: /style.css
requests: 1024
rounds: 5
warmup: 16
```

## Target definitions

Left target:

```text
name: DEADWIRE_LINUX
executable: ./build/deadwire
args: ""
port: 18080
```

Right target:

```text
name: NIHSERVER_PATCHED_SECTION
executable: ../nihserver/target/nihserver/nihserver
args: "19096 public 768"
port: 19096
```

The right target was a local external checkout with the syscall wrapper section marker changed from `.data` to `.text`. Keep these results separate from upstream nihserver results.

## Smoke proof

The patched external target started and listened on `0.0.0.0:19096`.

The smoke probes returned HTTP 200 for both paths:

```text
GET /          -> 200 OK
GET /style.css -> 200 OK
```

The target log showed repeated successful `/style.css` responses during the benchmark:

```text
[127.0.0.1:44404] (fd 593) -> /style.css
200 OK (772 bytes) -> [127.0.0.1:44404] (fd 593)
[127.0.0.1:44406] (fd 594) -> /style.css
200 OK (772 bytes) -> [127.0.0.1:44406] (fd 594)
```

## Score command

```sh
sh scripts/bench-score.sh \
  --left-name DEADWIRE_LINUX \
  --left-exe ./build/deadwire \
  --left-args "" \
  --left-port 18080 \
  --right-name NIHSERVER_PATCHED_SECTION \
  --right-exe ../nihserver/target/nihserver/nihserver \
  --right-args "19096 public 768" \
  --right-port 19096 \
  --path /style.css \
  --ready-path / \
  --requests 1024 \
  --rounds 5 \
  --warmup 16
```

## Raw summary

```text
DEADWIRE_LINUX 14417.28 0.069
NIHSERVER_PATCHED_SECTION 4710.15 0.212
bench-score: left=DEADWIRE_LINUX left_rps=14417.28 left_avg_ms=0.069 right=NIHSERVER_PATCHED_SECTION right_rps=4710.15 right_avg_ms=0.212 winner=DEADWIRE_LINUX rps_ratio=3.061 latency_ratio=3.072
```

## Result

```text
winner: DEADWIRE_LINUX
left_median_rps: 14417.28
left_median_avg_ms: 0.069
right_median_rps: 4710.15
right_median_avg_ms: 0.212
rps_ratio: 3.061
latency_ratio: 3.072
```

## Claim discipline

Allowed claim:

```text
DEADWIRE_LINUX was 3.061x faster by median RPS than nihserver patched-section in WSL close-mode on /style.css.
```

Do not claim this as a win over upstream nihserver without the `patched-section` label.
