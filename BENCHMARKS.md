# DEADWIRE HTTPD BENCHMARKS

LOCAL SMOKE MEASUREMENTS. USE THESE AS REPO BASELINES, NOT UNIVERSAL RESULTS.

ENVIRONMENT:

```txt
PLATFORM: WINDOWS
BRANCH: work-v1.2-io
MODE: SEQUENTIAL TCP REQUESTS
ROUNDS PER PATH: 5
CONNECTION STYLE: ONE REQUEST PER CONNECTION
```

## V1.2 STATIC COST BASELINE

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
```
