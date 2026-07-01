#!/usr/bin/env sh
set -eu

left_name=DEADWIRE
left_exe=./build/deadwire
left_args=19095
left_port=19095
left_existing=0
right_name=TARGET
right_exe=
right_args=19096
right_port=19096
right_existing=0
host=127.0.0.1
path=/style.css
ready_path=/
requests=1024
rounds=5
warmup=16
startup_timeout_ms=5000
keepalive=0

usage() {
  cat <<'USAGE'
usage: scripts/bench-score.sh \
  --left-name NAME --left-exe PATH --left-args "ARGS" --left-port PORT \
  --right-name NAME --right-exe PATH --right-args "ARGS" --right-port PORT \
  [--path /style.css] [--ready-path /] [--requests N] [--rounds N] [--warmup N] [--keepalive]

Use --left-existing or --right-existing when the server is already running.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --left-name) left_name=$2; shift 2 ;;
    --left-exe) left_exe=$2; shift 2 ;;
    --left-args) left_args=$2; shift 2 ;;
    --left-port) left_port=$2; shift 2 ;;
    --left-existing) left_existing=1; shift ;;
    --right-name) right_name=$2; shift 2 ;;
    --right-exe) right_exe=$2; shift 2 ;;
    --right-args) right_args=$2; shift 2 ;;
    --right-port) right_port=$2; shift 2 ;;
    --right-existing) right_existing=1; shift ;;
    --host) host=$2; shift 2 ;;
    --path) path=$2; shift 2 ;;
    --ready-path) ready_path=$2; shift 2 ;;
    --requests) requests=$2; shift 2 ;;
    --rounds) rounds=$2; shift 2 ;;
    --warmup) warmup=$2; shift 2 ;;
    --startup-timeout-ms) startup_timeout_ms=$2; shift 2 ;;
    --keepalive) keepalive=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "bench-score.sh: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

case "$path" in /*) ;; --head-health) ;; *) echo 'bench-score.sh: path must start with / or be --head-health' >&2; exit 1 ;; esac
case "$ready_path" in /*) ;; --head-health) ;; *) echo 'bench-score.sh: ready path must start with / or be --head-health' >&2; exit 1 ;; esac
[ "$requests" -ge 1 ] || { echo 'bench-score.sh: requests must be >= 1' >&2; exit 1; }
[ "$rounds" -ge 1 ] || { echo 'bench-score.sh: rounds must be >= 1' >&2; exit 1; }
[ "$warmup" -ge 0 ] || { echo 'bench-score.sh: warmup must be >= 0' >&2; exit 1; }
[ "$startup_timeout_ms" -ge 1 ] || { echo 'bench-score.sh: startup timeout must be >= 1' >&2; exit 1; }
[ "$right_existing" -eq 1 ] || [ -n "$right_exe" ] || { echo 'bench-score.sh: right executable is required unless --right-existing is set' >&2; exit 1; }

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build_dir=$root/build
bench_src=$root/tools/deadwire_bench.c
bench_exe=$build_dir/deadwire_score_bench
mkdir -p "$build_dir"
[ -f "$bench_src" ] || { echo "bench-score.sh: missing bench source: $bench_src" >&2; exit 1; }
cc_bin=${CC:-cc}
"$cc_bin" -D_POSIX_C_SOURCE=200809L -O2 -std=c99 -Wall -Wextra -o "$bench_exe" "$bench_src"

server_pid=
cleanup_server() {
  if [ -n "${server_pid:-}" ]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" 2>/dev/null || true
    server_pid=
  fi
}
trap cleanup_server EXIT INT TERM

run_one_side() {
  name=$1
  exe=$2
  args=$3
  port=$4
  existing=$5

  log=$build_dir/bench-score-$name.log
  rm -f "$log"
  if [ "$existing" -eq 0 ]; then
    [ -f "$exe" ] || { echo "bench-score.sh: missing server executable: $exe" >&2; exit 1; }
    # Intentional word splitting for simple server argument lists such as: "19096 public 8".
    "$exe" $args >"$log" 2>&1 &
    server_pid=$!
  fi

  ready=0
  attempts=$((startup_timeout_ms / 100))
  [ "$attempts" -ge 1 ] || attempts=1
  i=0
  while [ "$i" -lt "$attempts" ]; do
    if "$bench_exe" "$host" "$port" "$ready_path" 1 1 >/dev/null 2>&1; then
      ready=1
      break
    fi
    i=$((i + 1))
    sleep 0.1
  done
  [ "$ready" -eq 1 ] || { echo "bench-score.sh: server did not become ready: $name" >&2; [ -f "$log" ] && cat "$log" >&2 || true; exit 1; }

  if [ "$warmup" -gt 0 ]; then
    if [ "$keepalive" -eq 1 ]; then
      "$bench_exe" "$host" "$port" "$path" "$warmup" 1 --keepalive >/dev/null
    else
      "$bench_exe" "$host" "$port" "$path" "$warmup" 1 >/dev/null
    fi
  fi

  echo "bench-score-start: name=$name port=$port path=$path requests=$requests rounds=$rounds"
  if [ "$keepalive" -eq 1 ]; then
    output=$("$bench_exe" "$host" "$port" "$path" "$requests" "$rounds" --keepalive)
  else
    output=$("$bench_exe" "$host" "$port" "$path" "$requests" "$rounds")
  fi
  printf '%s\n' "$output"

  summary=$(printf '%s\n' "$output" | grep '^native-bench: ' | tail -n 1)
  rps=$(printf '%s\n' "$summary" | sed -n 's/.*median_rps=\([0-9.][0-9.]*\).*/\1/p')
  avg_ms=$(printf '%s\n' "$summary" | sed -n 's/.*median_avg_ms=\([0-9.][0-9.]*\).*/\1/p')
  [ -n "$rps" ] || { echo "bench-score.sh: missing rps summary for $name" >&2; exit 1; }
  [ -n "$avg_ms" ] || { echo "bench-score.sh: missing latency summary for $name" >&2; exit 1; }

  cleanup_server
  printf '%s %s %s\n' "$name" "$rps" "$avg_ms"
}

left_result=$(run_one_side "$left_name" "$left_exe" "$left_args" "$left_port" "$left_existing" | tee /dev/stderr | tail -n 1)
[ -n "$left_result" ] || { echo 'bench-score.sh: left side failed' >&2; exit 1; }
right_result=$(run_one_side "$right_name" "$right_exe" "$right_args" "$right_port" "$right_existing" | tee /dev/stderr | tail -n 1)
[ -n "$right_result" ] || { echo 'bench-score.sh: right side failed' >&2; exit 1; }

left_label=$(printf '%s' "$left_result" | awk '{print $1}')
left_rps=$(printf '%s' "$left_result" | awk '{print $2}')
left_avg=$(printf '%s' "$left_result" | awk '{print $3}')
right_label=$(printf '%s' "$right_result" | awk '{print $1}')
right_rps=$(printf '%s' "$right_result" | awk '{print $2}')
right_avg=$(printf '%s' "$right_result" | awk '{print $3}')

if awk -v l="$left_rps" -v r="$right_rps" 'BEGIN{exit !(l >= r)}'; then
  winner=$left_label
  rps_ratio=$(awk -v l="$left_rps" -v r="$right_rps" 'BEGIN{printf "%.3f", l / (r > 0 ? r : 0.000001)}')
  latency_ratio=$(awk -v l="$left_avg" -v r="$right_avg" 'BEGIN{printf "%.3f", r / (l > 0 ? l : 0.000001)}')
else
  winner=$right_label
  rps_ratio=$(awk -v l="$left_rps" -v r="$right_rps" 'BEGIN{printf "%.3f", r / (l > 0 ? l : 0.000001)}')
  latency_ratio=$(awk -v l="$left_avg" -v r="$right_avg" 'BEGIN{printf "%.3f", l / (r > 0 ? r : 0.000001)}')
fi

printf 'bench-score: left=%s left_rps=%.2f left_avg_ms=%.3f right=%s right_rps=%.2f right_avg_ms=%.3f winner=%s rps_ratio=%s latency_ratio=%s\n' \
  "$left_label" "$left_rps" "$left_avg" "$right_label" "$right_rps" "$right_avg" "$winner" "$rps_ratio" "$latency_ratio"
