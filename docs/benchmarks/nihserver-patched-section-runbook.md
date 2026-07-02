# nihserver patched-section benchmark runbook

This runbook is for a labeled compatibility experiment only. It is not an upstream nihserver result.

Use this label for every result produced by this path:

```text
DEADWIRE Linux vs nihserver patched-section, WSL, close-mode, /style.css
```

## Preconditions

Run from Ubuntu / WSL, with both repositories under `~/src`:

```text
~/src/DEADWIRE-HTTPD
~/src/nihserver
```

DEADWIRE must already pass its Linux verification:

```sh
cd ~/src/DEADWIRE-HTTPD
git switch main
git pull origin main
make clean
make
make verify
```

## Prepare the external target

This edits only the local `nihserver` checkout. It does not modify this repository and it must not be presented as an upstream nihserver build.

The upstream `syscall.s` has `global` declarations between the section marker and the first syscall wrapper, so replace the section marker itself.

```sh
cd ~/src/nihserver
cp src/nihserver/linux/syscall.s src/nihserver/linux/syscall.s.bak
perl -0pi -e 's/section \.data\n/section .text\n/' src/nihserver/linux/syscall.s
make clean
make
```

Confirm the marker changed:

```sh
grep -n 'section \.text' src/nihserver/linux/syscall.s | head
```

## Smoke test the external target

Start the patched external target from the `nihserver` repository:

```sh
cd ~/src/nihserver
target/nihserver/nihserver 19096 ../DEADWIRE-HTTPD/public 768
```

In another WSL shell:

```sh
curl -v http://127.0.0.1:19096/
curl -v http://127.0.0.1:19096/style.css
```

Do not run a score benchmark until both curl probes reach the target.

## Run the score benchmark

Run from the DEADWIRE repository:

```sh
cd ~/src/DEADWIRE-HTTPD
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

## Result capture template

Paste the final result using this shape:

```text
benchmark: DEADWIRE Linux vs nihserver patched-section
host: WSL
mode: close
path: /style.css
requests: 1024
rounds: 5
warmup: 16
DEADWIRE_LINUX median_rps: ...
DEADWIRE_LINUX median_avg_ms: ...
NIHSERVER_PATCHED_SECTION median_rps: ...
NIHSERVER_PATCHED_SECTION median_avg_ms: ...
winner: ...
rps_ratio: ...
latency_ratio: ...
```

## Restore nihserver checkout

After the experiment, restore the external checkout:

```sh
cd ~/src/nihserver
mv src/nihserver/linux/syscall.s.bak src/nihserver/linux/syscall.s
make clean
make
```

## Claim discipline

A patched-section score is useful for engineering comparison, but it is not an upstream nihserver claim. Keep patched-target results separate from upstream-target results.
