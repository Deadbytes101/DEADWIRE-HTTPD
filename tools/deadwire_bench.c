#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
typedef SOCKET socket_t;
#define close_socket closesocket
#else
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>
typedef int socket_t;
#define INVALID_SOCKET (-1)
#define SOCKET_ERROR (-1)
#define close_socket close
#endif

typedef struct BenchRound {
    double seconds;
    double rps;
    double avg_ms;
    long long bytes;
} BenchRound;

static double now_seconds(void) {
#ifdef _WIN32
    static LARGE_INTEGER frequency;
    LARGE_INTEGER counter;
    if (frequency.QuadPart == 0) {
        QueryPerformanceFrequency(&frequency);
    }
    QueryPerformanceCounter(&counter);
    return (double)counter.QuadPart / (double)frequency.QuadPart;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0;
#endif
}

static int parse_int(const char *text, int min_value, int max_value, const char *name, int *out) {
    char *end = NULL;
    long value = 0;

    errno = 0;
    value = strtol(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0' || value < min_value || value > max_value) {
        fprintf(stderr, "native-bench: invalid %s: %s\n", name, text);
        return 1;
    }

    *out = (int)value;
    return 0;
}

static int send_all_bytes(socket_t sock, const char *buf, int len) {
    int offset = 0;
    while (offset < len) {
        int sent = send(sock, buf + offset, len - offset, 0);
        if (sent <= 0) {
            return 1;
        }
        offset += sent;
    }
    return 0;
}

static int run_one(const char *host, int port, const char *path, long long *bytes_out) {
    socket_t sock = INVALID_SOCKET;
    struct sockaddr_in addr;
    char request[1024];
    char buffer[8192];
    int request_len = 0;
    int connect_only = strcmp(path, "--connect-only") == 0;
    long long total = 0;

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons((unsigned short)port);

#ifdef _WIN32
    addr.sin_addr.s_addr = inet_addr(host);
    if (addr.sin_addr.s_addr == INADDR_NONE) {
        fprintf(stderr, "native-bench: host must be IPv4 dotted decimal: %s\n", host);
        return 1;
    }
#else
    if (inet_pton(AF_INET, host, &addr.sin_addr) != 1) {
        fprintf(stderr, "native-bench: host must be IPv4 dotted decimal: %s\n", host);
        return 1;
    }
#endif

    if (!connect_only) {
        request_len = snprintf(request, sizeof(request), "GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", path, host);
        if (request_len <= 0 || request_len >= (int)sizeof(request)) {
            fprintf(stderr, "native-bench: request too large\n");
            return 1;
        }
    }

    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock == INVALID_SOCKET) {
        fprintf(stderr, "native-bench: socket failed\n");
        return 1;
    }

    if (connect(sock, (struct sockaddr *)&addr, (int)sizeof(addr)) == SOCKET_ERROR) {
        close_socket(sock);
        return 1;
    }

    if (connect_only) {
        close_socket(sock);
        *bytes_out = 0;
        return 0;
    }

    if (send_all_bytes(sock, request, request_len) != 0) {
        close_socket(sock);
        return 1;
    }

    for (;;) {
        int got = recv(sock, buffer, (int)sizeof(buffer), 0);
        if (got == 0) {
            break;
        }
        if (got < 0) {
            close_socket(sock);
            return 1;
        }
        total += got;
    }

    close_socket(sock);
    *bytes_out = total;
    return 0;
}

static int cmp_round_seconds(const void *a, const void *b) {
    const BenchRound *ra = (const BenchRound *)a;
    const BenchRound *rb = (const BenchRound *)b;
    if (ra->seconds < rb->seconds) {
        return -1;
    }
    if (ra->seconds > rb->seconds) {
        return 1;
    }
    return 0;
}

static BenchRound median_round(BenchRound *rounds, int count) {
    BenchRound *copy = (BenchRound *)calloc((size_t)count, sizeof(BenchRound));
    BenchRound out;
    int mid = count / 2;

    if (copy == NULL) {
        fprintf(stderr, "native-bench: out of memory\n");
        exit(2);
    }

    memcpy(copy, rounds, (size_t)count * sizeof(BenchRound));
    qsort(copy, (size_t)count, sizeof(BenchRound), cmp_round_seconds);

    if ((count % 2) == 1) {
        out = copy[mid];
    } else {
        out.seconds = (copy[mid - 1].seconds + copy[mid].seconds) / 2.0;
        out.rps = (copy[mid - 1].rps + copy[mid].rps) / 2.0;
        out.avg_ms = (copy[mid - 1].avg_ms + copy[mid].avg_ms) / 2.0;
        out.bytes = copy[mid].bytes;
    }

    free(copy);
    return out;
}

int main(int argc, char **argv) {
    const char *host = NULL;
    const char *path = NULL;
    int port = 0;
    int requests = 0;
    int rounds_count = 0;
    BenchRound *rounds = NULL;
    double min_rps = 0.0;
    double max_rps = 0.0;
    BenchRound median;

#ifdef _WIN32
    WSADATA wsa;
    if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) {
        fprintf(stderr, "native-bench: WSAStartup failed\n");
        return 1;
    }
#endif

    if (argc != 6) {
        fprintf(stderr, "usage: deadwire_bench <host> <port> <path|--connect-only> <requests> <rounds>\n");
#ifdef _WIN32
        WSACleanup();
#endif
        return 1;
    }

    host = argv[1];
    path = argv[3];

    if (parse_int(argv[2], 1, 65535, "port", &port) != 0 ||
        parse_int(argv[4], 1, 10000000, "requests", &requests) != 0 ||
        parse_int(argv[5], 1, 1000, "rounds", &rounds_count) != 0) {
#ifdef _WIN32
        WSACleanup();
#endif
        return 1;
    }

    if (path[0] != '/' && strcmp(path, "--connect-only") != 0) {
        fprintf(stderr, "native-bench: path must start with / or be --connect-only\n");
#ifdef _WIN32
        WSACleanup();
#endif
        return 1;
    }

    rounds = (BenchRound *)calloc((size_t)rounds_count, sizeof(BenchRound));
    if (rounds == NULL) {
        fprintf(stderr, "native-bench: out of memory\n");
#ifdef _WIN32
        WSACleanup();
#endif
        return 1;
    }

    for (int round = 0; round < rounds_count; round++) {
        double start = 0.0;
        double end = 0.0;
        long long bytes = 0;

        start = now_seconds();
        for (int i = 0; i < requests; i++) {
            long long one_bytes = 0;
            if (run_one(host, port, path, &one_bytes) != 0) {
                fprintf(stderr, "native-bench: request failed at round=%d request=%d\n", round + 1, i + 1);
                free(rounds);
#ifdef _WIN32
                WSACleanup();
#endif
                return 1;
            }
            bytes += one_bytes;
        }
        end = now_seconds();

        rounds[round].seconds = end - start;
        if (rounds[round].seconds <= 0.0) {
            rounds[round].seconds = 0.000001;
        }
        rounds[round].rps = (double)requests / rounds[round].seconds;
        rounds[round].avg_ms = (rounds[round].seconds * 1000.0) / (double)requests;
        rounds[round].bytes = bytes;

        if (round == 0 || rounds[round].rps < min_rps) {
            min_rps = rounds[round].rps;
        }
        if (round == 0 || rounds[round].rps > max_rps) {
            max_rps = rounds[round].rps;
        }

        printf("native-bench-round: path=%s round=%d/%d requests=%d seconds=%.3f rps=%.2f avg_ms=%.3f bytes=%lld\n",
               path, round + 1, rounds_count, requests, rounds[round].seconds, rounds[round].rps, rounds[round].avg_ms, rounds[round].bytes);
    }

    median = median_round(rounds, rounds_count);
    printf("native-bench: path=%s rounds=%d requests=%d median_seconds=%.3f median_rps=%.2f median_avg_ms=%.3f min_rps=%.2f max_rps=%.2f bytes=%lld\n",
           path, rounds_count, requests, median.seconds, median.rps, median.avg_ms, min_rps, max_rps, rounds[0].bytes);

    free(rounds);
#ifdef _WIN32
    WSACleanup();
#endif
    return 0;
}
