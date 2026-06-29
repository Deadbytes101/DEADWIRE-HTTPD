# DEADWIRE HTTPD BENCHMARKS

LOCAL SMOKE MEASUREMENTS. USE THESE AS REPO BASELINES, NOT UNIVERSAL RESULTS.

ENVIRONMENT:

```txt
PLATFORM: WINDOWS
BRANCH: feat/v1.3-keepalive
MODE: SEQUENTIAL TCP REQUESTS
ROUNDS PER PATH: 5
DEFAULT CONNECTION STYLE: ONE REQUEST PER CONNECTION
KEEP-ALIVE FLAVOR STYLE: MANY REQUESTS PER CONNECTION ROUND
```

## V1.3 NATIVE KEEP-ALIVE STABLE FLAVOR BENCH

Native C/WinSock client with 32768 requests per round against the stable opt-in keep-alive build flavor:

```txt
build/deadwire_keepalive.exe
```

This is a connection-reuse benchmark, not a concurrency benchmark. The server remains blocking and single-threaded.

```txt
/health
  rounds:         5
  requests:       32768
  median_seconds: 4.539
  median_rps:     7,219.95
  median_avg_ms:  0.139
  min_rps:        6,601.44
  max_rps:        11,050.25
  bytes:          3833856

/hello.txt
  rounds:         5
  requests:       32768
  median_seconds: 5.338
  median_rps:     6,138.54
  median_avg_ms:  0.163
  min_rps:        5,435.69
  max_rps:        6,326.50
  bytes:          4096000

/missing-bench.txt
  rounds:         5
  requests:       32768
  median_seconds: 4.669
  median_rps:     7,018.10
  median_avg_ms:  0.142
  min_rps:        6,189.75
  max_rps:        8,028.55
  bytes:          4096000

/
  rounds:         5
  requests:       32768
  median_seconds: 5.875
  median_rps:     5,577.20
  median_avg_ms:  0.179
  min_rps:        4,671.50
  max_rps:        6,274.44
  bytes:          46235648
```

STABLE KEEP-ALIVE READ AGAINST V1.2 QUIET BASELINE:

```txt
health_avg_ms_delta:  -0.009
hello_avg_ms_delta:   -0.037
missing_avg_ms_delta: -0.030
index_avg_ms_delta:   -0.011

health_rps_gain:   7.1%
hello_rps_gain:    22.5%
missing_rps_gain:  20.4%
index_rps_gain:    6.1%
```

COMMANDS:

```txt
make build-keepalive
make verify-keepalive
make bench-native-keepalive
```

## V1.2 NATIVE QUIET BENCH BASELINE

Native C/WinSock client with 32768 requests per round against an access-log-off generated build. Unlike the no-log diagnostic build, this keeps banner/fatal output and disables only per-request access log call sites.

```txt
/health
  rounds:         5
  requests:       32768
  median_seconds: 4.863
  median_rps:     6,738.40
  median_avg_ms:  0.148
  min_rps:        6,642.15
  max_rps:        6,821.07
  bytes:          3670016

/missing-bench.txt
  rounds:         5
  requests:       32768
  median_seconds: 5.621
  median_rps:     5,829.34
  median_avg_ms:  0.172
  min_rps:        5,752.53
  max_rps:        6,216.90
  bytes:          3932160

/hello.txt
  rounds:         5
  requests:       32768
  median_seconds: 6.539
  median_rps:     5,011.23
  median_avg_ms:  0.200
  min_rps:        4,868.67
  max_rps:        5,083.20
  bytes:          3932160

/
  rounds:         5
  requests:       32768
  median_seconds: 6.236
  median_rps:     5,254.81
  median_avg_ms:  0.190
  min_rps:        5,014.76
  max_rps:        5,395.44
  bytes:          46071808
```

QUIET READ AGAINST XXL:

```txt
health_saved_avg_ms:  0.093
missing_saved_avg_ms: 0.113
hello_saved_avg_ms:   0.115
index_saved_avg_ms:   0.119

health_rps_gain:  62.2%
missing_rps_gain: 66.3%
hello_rps_gain:   57.8%
index_rps_gain:   62.6%
```

QUIET VS NO-LOG READ:

```txt
health_quiet_vs_nolog_avg_ms:  0.000
missing_quiet_vs_nolog_avg_ms: -0.001
hello_quiet_vs_nolog_avg_ms:   0.002
index_quiet_vs_nolog_avg_ms:  -0.008
```

## V1.2 NATIVE NO-LOG BENCH BASELINE

Native C/WinSock client with 32768 requests per round against a diagnostic generated build where `write_stdout` is stubbed out. This is not the production binary; it measures access-log cost.

```txt
/health
  rounds:         5
  requests:       32768
  median_seconds: 4.865
  median_rps:     6,735.41
  median_avg_ms:  0.148
  min_rps:        6,496.27
  max_rps:        7,005.95
  bytes:          3670016

/missing-bench.txt
  rounds:         5
  requests:       32768
  median_seconds: 5.667
  median_rps:     5,782.70
  median_avg_ms:  0.173
  min_rps:        5,647.10
  max_rps:        5,971.46
  bytes:          3932160

/hello.txt
  rounds:         5
  requests:       32768
  median_seconds: 6.488
  median_rps:     5,050.39
  median_avg_ms:  0.198
  min_rps:        4,875.73
  max_rps:        5,213.61
  bytes:          3932160

/
  rounds:         5
  requests:       32768
  median_seconds: 6.504
  median_rps:     5,038.20
  median_avg_ms:  0.198
  min_rps:        4,745.95
  max_rps:        5,327.73
  bytes:          46071808
```

NO-LOG READ AGAINST XXL:

```txt
health_saved_avg_ms:  0.093
missing_saved_avg_ms: 0.112
hello_saved_avg_ms:   0.117
index_saved_avg_ms:   0.111

health_rps_gain:  62.1%
missing_rps_gain: 65.0%
hello_rps_gain:   59.0%
index_rps_gain:   55.9%
```

## V1.2 NATIVE LIFECYCLE BENCH BASELINE

Native C/WinSock client using `HEAD /health` with one request per connection. This is the safest lifecycle proxy after pure connect/close hit client-side port/TIME_WAIT limits during long runs.

```txt
--head-health
  rounds:         5
  requests:       16384
  median_seconds: 3.904
  median_rps:     4,197.22
  median_avg_ms:  0.238
  min_rps:        4,099.87
  max_rps:        4,395.19
  bytes:          1622016
```

LIFECYCLE READ:

```txt
head_health_avg_ms:     0.238
get_health_xxl_avg_ms:  0.241
head_vs_get_health_ms: -0.003
```

## V1.2 XXL NATIVE BENCH BASELINE

Native C/WinSock client with 32768 requests per round. This is the longest one-connection-per-request baseline currently recorded.

```txt
/health
  rounds:         5
  requests:       32768
  median_seconds: 7.888
  median_rps:     4,154.31
  median_avg_ms:  0.241
  min_rps:        3,956.01
  max_rps:        4,208.15
  bytes:          3670016

/missing-bench.txt
  rounds:         5
  requests:       32768
  median_seconds: 9.346
  median_rps:     3,506.11
  median_avg_ms:  0.285
  min_rps:        3,443.89
  max_rps:        3,582.14
  bytes:          3932160

/hello.txt
  rounds:         5
  requests:       32768
  median_seconds: 10.318
  median_rps:     3,175.82
  median_avg_ms:  0.315
  min_rps:        3,138.59
  max_rps:        3,245.77
  bytes:          3932160

/
  rounds:         5
  requests:       32768
  median_seconds: 10.138
  median_rps:     3,232.13
  median_avg_ms:  0.309
  min_rps:        3,178.28
  max_rps:        3,332.36
  bytes:          46071808
```

XXL NATIVE COST READ:

```txt
missing_over_health_avg_ms: 0.044
hello_over_missing_avg_ms: 0.030
index_over_hello_avg_ms:   -0.006
```

## V1.2 XL NATIVE BENCH BASELINE

Native C/WinSock client with 16384 requests per round.

```txt
/health
  rounds:         5
  requests:       16384
  median_seconds: 4.204
  median_rps:     3,897.65
  median_avg_ms:  0.257
  min_rps:        3,844.69
  max_rps:        3,969.08
  bytes:          1835008

/missing-bench.txt
  rounds:         5
  requests:       16384
  median_seconds: 4.712
  median_rps:     3,477.11
  median_avg_ms:  0.288
  min_rps:        3,452.09
  max_rps:        3,600.52
  bytes:          1966080

/hello.txt
  rounds:         5
  requests:       16384
  median_seconds: 5.003
  median_rps:     3,274.74
  median_avg_ms:  0.305
  min_rps:        3,185.78
  max_rps:        3,329.48
  bytes:          1966080

/
  rounds:         5
  requests:       16384
  median_seconds: 5.181
  median_rps:     3,162.39
  median_avg_ms:  0.316
  min_rps:        3,122.42
  max_rps:        3,180.92
  bytes:          23035904
```

XL NATIVE COST READ:

```txt
missing_over_health_avg_ms: 0.031
hello_over_missing_avg_ms: 0.017
index_over_hello_avg_ms:   0.011
```

## V1.2 LONG NATIVE BENCH BASELINE

Native C/WinSock client with 4096 requests per round. This is the preferred baseline for optimization decisions because it reduces short-run noise.

```txt
/health
  rounds:         5
  requests:       4096
  median_seconds: 0.951
  median_rps:     4,307.01
  median_avg_ms:  0.232
  min_rps:        4,029.21
  max_rps:        4,576.84
  bytes:          458752

/missing-bench.txt
  rounds:         5
  requests:       4096
  median_seconds: 1.013
  median_rps:     4,043.81
  median_avg_ms:  0.247
  min_rps:        3,929.87
  max_rps:        4,086.74
  bytes:          491520

/hello.txt
  rounds:         5
  requests:       4096
  median_seconds: 1.108
  median_rps:     3,696.29
  median_avg_ms:  0.271
  min_rps:        3,358.44
  max_rps:        3,944.60
  bytes:          491520

/
  rounds:         5
  requests:       4096
  median_seconds: 1.130
  median_rps:     3,624.36
  median_avg_ms:  0.276
  min_rps:        3,377.82
  max_rps:        3,925.50
  bytes:          5758976
```

LONG NATIVE COST READ:

```txt
missing_over_health_avg_ms: 0.015
hello_over_missing_avg_ms: 0.024
index_over_hello_avg_ms:   0.005
```

## V1.2 NATIVE BENCH BASELINE

Native C/WinSock client. This is the preferred optimization baseline over the PowerShell/.NET smoke bench.

```txt
/health
  rounds:         5
  requests:       1024
  median_seconds: 0.219
  median_rps:     4,667.46
  median_avg_ms:  0.214
  min_rps:        3,983.24
  max_rps:        4,766.01
  bytes:          114688

/missing-bench.txt
  rounds:         5
  requests:       1024
  median_seconds: 0.270
  median_rps:     3,797.99
  median_avg_ms:  0.263
  min_rps:        3,135.72
  max_rps:        4,096.69
  bytes:          122880

/hello.txt
  rounds:         5
  requests:       1024
  median_seconds: 0.264
  median_rps:     3,883.08
  median_avg_ms:  0.258
  min_rps:        3,483.28
  max_rps:        3,977.17
  bytes:          122880

/
  rounds:         5
  requests:       1024
  median_seconds: 0.263
  median_rps:     3,893.10
  median_avg_ms:  0.257
  min_rps:        3,487.96
  max_rps:        3,918.26
  bytes:          1439744
```

NATIVE COST READ:

```txt
missing_over_health_avg_ms: 0.049
hello_over_missing_avg_ms: -0.005
index_over_hello_avg_ms:   -0.001
```

## V1.2 STATIC COST BASELINE

PowerShell/.NET smoke client. Kept for historical continuity; use native bench for optimization decisions.

```txt
/health
  rounds:         5
  requests:       1024
  median_seconds: 0.322
  median_rps:     3,182.78
  median_avg_ms:  0.314
  min_rps:        2,729.08
  max_rps:        3,213.10
  bytes:          114688

/missing-bench.txt
  rounds:         5
  requests:       1024
  median_seconds: 0.369
  median_rps:     2,775.16
  median_avg_ms:  0.360
  min_rps:        2,686.86
  max_rps:        2,808.04
  bytes:          122880

/hello.txt
  rounds:         5
  requests:       1024
  median_seconds: 0.396
  median_rps:     2,588.73
  median_avg_ms:  0.386
  min_rps:        2,419.78
  max_rps:        2,623.85
  bytes:          122880

/
  rounds:         5
  requests:       1024
  median_seconds: 0.397
  median_rps:     2,578.22
  median_avg_ms:  0.388
  min_rps:        2,337.29
  max_rps:        2,656.96
  bytes:          1439744
```

STATIC COST READ:

```txt
missing_over_health_avg_ms: 0.046
hello_over_missing_avg_ms: 0.026
index_over_hello_avg_ms:   0.002
```

## V1.2 I/O DISCIPLINE LONG MEDIAN BASELINE

```txt
/health
  rounds:         5
  requests:       1024
  median_seconds: 0.365
  median_rps:     2,809.29
  median_avg_ms:  0.356
  min_rps:        2,779.73
  max_rps:        2,925.02
  bytes:          114688

/
  rounds:         5
  requests:       1024
  median_seconds: 0.407
  median_rps:     2,517.10
  median_avg_ms:  0.397
  min_rps:        2,460.98
  max_rps:        2,589.17
  bytes:          1439744

/hello.txt
  rounds:         5
  requests:       1024
  median_seconds: 0.419
  median_rps:     2,445.05
  median_avg_ms:  0.409
  min_rps:        2,338.86
  max_rps:        2,677.30
  bytes:          122880
```

## V1.2 I/O DISCIPLINE SHORT MEDIAN BASELINE

```txt
/health
  rounds:         5
  requests:       256
  median_seconds: 0.075
  median_rps:     3,427.27
  median_avg_ms:  0.292
  min_rps:        2,909.55
  max_rps:        3,597.74
  bytes:          28672

/
  rounds:         5
  requests:       256
  median_seconds: 0.098
  median_rps:     2,613.28
  median_avg_ms:  0.383
  min_rps:        2,199.87
  max_rps:        2,754.70
  bytes:          359936

/hello.txt
  rounds:         5
  requests:       256
  median_seconds: 0.103
  median_rps:     2,495.66
  median_avg_ms:  0.401
  min_rps:        2,086.24
  max_rps:        2,653.63
  bytes:          30720
```

## PRE-MEDIAN SMOKE BASELINE

```txt
/health
  requests: 256
  seconds:  0.098
  rps:      2,622.43
  avg_ms:   0.381
  bytes:    28672

/
  requests: 256
  seconds:  0.116
  rps:      2,202.17
  avg_ms:   0.454
  bytes:    359936

/hello.txt
  requests: 256
  seconds:  0.128
  rps:      1,996.70
  avg_ms:   0.501
  bytes:    30720
```

COMMANDS:

```txt
make bench
make bench-long
make bench-cost
make bench-native
make bench-native-long
make bench-native-xl
make bench-native-xxl
make bench-native-lifecycle
make bench-native-nolog
make build-quiet
make bench-native-quiet
make build-keepalive
make verify-keepalive
make bench-native-keepalive
```
