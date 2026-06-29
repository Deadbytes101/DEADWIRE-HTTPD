# DEADWIRE HTTPD BENCHMARKS

BASELINE NUMBERS ARE LOCAL SMOKE MEASUREMENTS, NOT FINAL CROSS-MACHINE CLAIMS.

ENVIRONMENT:

```txt
PLATFORM: WINDOWS
BRANCH: work-v1.2-io
MODE: SEQUENTIAL TCP REQUESTS
REQUESTS PER PATH: 256
ROUNDS PER PATH: 5
CONNECTION STYLE: ONE REQUEST PER CONNECTION
```

## V1.2 I/O DISCIPLINE MEDIAN BASELINE

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

READ THIS CORRECTLY:

```txt
THIS IS NOT A FINAL PUBLIC PERFORMANCE CLAIM.
THIS IS THE FIRST REPO-TRACKED BASELINE.
EVERY OPTIMIZATION AFTER THIS MUST BE MEASURED AGAINST IT.
```

COMMAND:

```sh
make bench
```
