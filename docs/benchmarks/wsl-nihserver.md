# WSL / Linux benchmark lane

This document keeps the benchmark lanes honest:

- Windows lane: benchmark `build/deadwire.exe` on Win11 with the PowerShell harness.
- WSL / Linux lane: benchmark Linux binaries with the shell harness.
- Do not mix Windows DEADWIRE numbers with Linux nihserver numbers as a final claim. Treat cross-OS numbers as exploration only.

## Why this lane exists

`winstonli/nihserver` is an x86-64 Linux assembly server. It builds with `nasm`, `make`, and `ld`, and its executable is `target/nihserver/nihserver`.

DEADWIRE also has a Linux target in this repository (`build/deadwire`). That makes WSL a useful place to run an apples-to-apples Linux lane:

```text
DEADWIRE Linux build  vs  nihserver Linux build
same WSL distro
same host
same path
same request count
same rounds
same warmup
```

## WSL setup

From an elevated Windows PowerShell, install WSL if it is not installed yet:

```powershell
wsl --install -d Ubuntu
wsl --set-default-version 2
```

Then enter Ubuntu / WSL and install the build tools:

```sh
sudo apt update
sudo apt install -y build-essential nasm make git
```

## Build DEADWIRE in WSL

Clone or enter this repository inside the WSL filesystem. Prefer `~/src/...` over `/mnt/c/...` for cleaner filesystem performance.

```sh
mkdir -p ~/src
cd ~/src
git clone https://github.com/Deadbytes101/DEADWIRE-HTTPD.git
cd DEADWIRE-HTTPD
make
make verify
```

The Linux DEADWIRE binary should be:

```text
build/deadwire
```

The current Linux assembly build listens on port `18080`.

## Build nihserver in WSL

```sh
cd ~/src
git clone https://github.com/winstonli/nihserver.git
cd nihserver
make
```

The nihserver binary should be:

```text
target/nihserver/nihserver
```

If nihserver exits before listening with a `syscall_stat` crash, see `docs/benchmarks/nihserver-compat.md`. Keep that result labeled as an external target compatibility experiment.

## Run a Linux-lane score

Run this from the DEADWIRE repository inside WSL:

```sh
sh scripts/bench-score.sh \
  --left-name DEADWIRE_LINUX \
  --left-exe ./build/deadwire \
  --left-args "" \
  --left-port 18080 \
  --right-name NIHSERVER \
  --right-exe ../nihserver/target/nihserver/nihserver \
  --right-args "19096 public 8" \
  --right-port 19096 \
  --path /style.css \
  --ready-path / \
  --requests 1024 \
  --rounds 5 \
  --warmup 16
```

Use `/style.css` or `/` for the first comparisons because both servers can serve static files from `public`. Avoid `/health` for nihserver unless you create a matching `health` file in the served directory.

## Interpret the output

The final line looks like this:

```text
bench-score: left=DEADWIRE_LINUX left_rps=... left_avg_ms=... right=NIHSERVER right_rps=... right_avg_ms=... winner=... rps_ratio=... latency_ratio=...
```

Rules:

- `rps_ratio` tells how much faster the winner is by median requests per second.
- `latency_ratio` tells how much better the winner is by median average latency.
- Repeat the run before making a claim. If the ratio is under 1.05, treat it as noise until repeated.
- Close-mode and keep-alive mode are different battles. Label them separately.

## Keep-alive lane

If both servers handle keep-alive correctly for the chosen path, add `--keepalive`:

```sh
sh scripts/bench-score.sh \
  --left-name DEADWIRE_LINUX \
  --left-exe ./build/deadwire \
  --left-args "" \
  --left-port 18080 \
  --right-name NIHSERVER \
  --right-exe ../nihserver/target/nihserver/nihserver \
  --right-args "19096 public 8" \
  --right-port 19096 \
  --path /style.css \
  --ready-path / \
  --requests 4096 \
  --rounds 5 \
  --warmup 64 \
  --keepalive
```

If either side fails keep-alive, keep that result separate. Do not silently fall back to close-mode.
