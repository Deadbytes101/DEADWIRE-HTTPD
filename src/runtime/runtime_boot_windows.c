#include <stdint.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

extern int dw_runtime_worker_init(uint64_t *worker, uint64_t id, uint64_t *input_queue, uint64_t *output_queue);
extern int dw_runtime_live_open(uint64_t *live_context);
extern int dw_runtime_live_close(uint64_t *live_context);
extern int dw_runtime_mode_bound(uint64_t *mode_context);

#define DEADWIRE_SMOKE_REQUESTS 4
#define DEADWIRE_QUEUE_CAPACITY 4
#define DEADWIRE_SENTINEL_SOCKET ((SOCKET)99)
#define DEADWIRE_LONG_STOP_NONE 0
#define DEADWIRE_LONG_STOP_TARGET 1
#define DEADWIRE_LONG_STOP_ERROR 2

static uint64_t input_items[DEADWIRE_QUEUE_CAPACITY];
static uint64_t output_items[DEADWIRE_QUEUE_CAPACITY];
static uint64_t input_queue[4];
static uint64_t output_queue[4];
static uint64_t worker_context[5];
static uint64_t live_context[5];
static uint64_t client_context[4];
static uint64_t tick_context[7];
static uint64_t bound_context[4];
static uint64_t mode_context[2];
static uint64_t loop_context[3];
static uint64_t long_context[5];
static uint64_t response_context[6];
static char request_buffer[512];
static char response_buffer[1024];

static const char health_get_request[] = "GET /health HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
static const char health_head_request[] = "HEAD /health HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
static const char health_status[] = "HTTP/1.0 200 OK\r\n";
static const char health_connection[] = "Connection: close\r\n";
static const char health_type_line[] = "Content-Type: text/plain\r\n";
static const char health_length[] = "Content-Length: 13\r\n";
static const char health_type[] = "text/plain";
static const char health_body[] = "deadwire: ok\n";

static int deadwire_contains(const char *buffer, int length, const char *needle, int needle_length) {
    int i;
    int j;

    if (!buffer || !needle || length <= 0 || needle_length <= 0 || length < needle_length) {
        return 0;
    }

    for (i = 0; i <= length - needle_length; ++i) {
        for (j = 0; j < needle_length; ++j) {
            if (buffer[i + j] != needle[j]) {
                break;
            }
        }
        if (j == needle_length) {
            return 1;
        }
    }

    return 0;
}

static int deadwire_response_has_body(const char *buffer, int length) {
    int i;

    if (!buffer || length < 4) {
        return 1;
    }

    for (i = 0; i <= length - 4; ++i) {
        if (buffer[i] == '\r' && buffer[i + 1] == '\n' && buffer[i + 2] == '\r' && buffer[i + 3] == '\n') {
            return (i + 4) < length;
        }
    }

    return 1;
}

static void deadwire_close_socket_if_real(SOCKET socket_value) {
    if (socket_value != INVALID_SOCKET && socket_value != 0 && socket_value != DEADWIRE_SENTINEL_SOCKET) {
        closesocket(socket_value);
    }
}

static void deadwire_close_client_socket(void) {
    deadwire_close_socket_if_real((SOCKET)client_context[0]);
    client_context[0] = (uint64_t)DEADWIRE_SENTINEL_SOCKET;
}

static void deadwire_close_peer_socket(SOCKET *socket_value) {
    if (*socket_value != INVALID_SOCKET) {
        closesocket(*socket_value);
        *socket_value = INVALID_SOCKET;
    }
}

static int deadwire_shutdown_live(void) {
    if (dw_runtime_live_close(live_context)) {
        return 0;
    }

    if (live_context[0] != 0 || live_context[4] != 0) {
        return 0;
    }

    if ((SOCKET)client_context[0] != DEADWIRE_SENTINEL_SOCKET) {
        return 0;
    }

    if (dw_runtime_live_close(live_context)) {
        return 0;
    }

    if (live_context[0] != 0 || live_context[4] != 0) {
        return 0;
    }

    return 1;
}

static int deadwire_finish_long_mode(int result_code, int shutdown_failure_code) {
    if (!deadwire_shutdown_live()) {
        long_context[3] = (uint64_t)shutdown_failure_code;
        long_context[4] = (uint64_t)shutdown_failure_code;
        return shutdown_failure_code;
    }

    long_context[3] = (uint64_t)result_code;
    long_context[4] = 0;
    return result_code;
}

static void deadwire_prepare_tick(void) {
    client_context[0] = (uint64_t)DEADWIRE_SENTINEL_SOCKET;
    client_context[1] = (uint64_t)request_buffer;
    client_context[2] = sizeof(request_buffer);
    client_context[3] = (uint64_t)response_context;

    tick_context[5] = 99;
    tick_context[6] = 99;

    bound_context[1] = 1;
    bound_context[2] = 99;
    bound_context[3] = 99;

    mode_context[1] = 99;
}

static void deadwire_prepare_loop(void) {
    loop_context[0] = DEADWIRE_SMOKE_REQUESTS;
    loop_context[1] = 0;
    loop_context[2] = 99;
}

static void deadwire_prepare_long_mode(void) {
    long_context[0] = DEADWIRE_SMOKE_REQUESTS;
    long_context[1] = 0;
    long_context[2] = DEADWIRE_LONG_STOP_NONE;
    long_context[3] = 99;
    long_context[4] = 99;
}

static int deadwire_run_health_request(struct sockaddr_in *bound_addr, int request_index) {
    SOCKET peer_socket = INVALID_SOCKET;
    const char *request;
    int request_length;
    int expect_body;
    int received;
    uint64_t expected_cursor;

    deadwire_prepare_tick();

    expect_body = (request_index & 1) == 0;
    request = expect_body ? health_get_request : health_head_request;
    request_length = expect_body ? (int)(sizeof(health_get_request) - 1) : (int)(sizeof(health_head_request) - 1);

    peer_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (peer_socket == INVALID_SOCKET) {
        return 20 + request_index;
    }

    if (connect(peer_socket, (struct sockaddr *)bound_addr, sizeof(*bound_addr))) {
        deadwire_close_peer_socket(&peer_socket);
        return 30 + request_index;
    }

    if (send(peer_socket, request, request_length, 0) != request_length) {
        deadwire_close_peer_socket(&peer_socket);
        return 40 + request_index;
    }

    if (dw_runtime_mode_bound(mode_context)) {
        deadwire_close_client_socket();
        deadwire_close_peer_socket(&peer_socket);
        return 50 + request_index;
    }

    received = recv(peer_socket, response_buffer, (int)(sizeof(response_buffer) - 1), 0);
    if (received <= 0) {
        deadwire_close_client_socket();
        deadwire_close_peer_socket(&peer_socket);
        return 60 + request_index;
    }
    response_buffer[received] = 0;

    if (!deadwire_contains(response_buffer, received, health_status, (int)(sizeof(health_status) - 1))) {
        deadwire_close_client_socket();
        deadwire_close_peer_socket(&peer_socket);
        return 70 + request_index;
    }

    if (!deadwire_contains(response_buffer, received, health_connection, (int)(sizeof(health_connection) - 1))) {
        deadwire_close_client_socket();
        deadwire_close_peer_socket(&peer_socket);
        return 75 + request_index;
    }

    if (!deadwire_contains(response_buffer, received, health_type_line, (int)(sizeof(health_type_line) - 1))) {
        deadwire_close_client_socket();
        deadwire_close_peer_socket(&peer_socket);
        return 77 + request_index;
    }

    if (!deadwire_contains(response_buffer, received, health_length, (int)(sizeof(health_length) - 1))) {
        deadwire_close_client_socket();
        deadwire_close_peer_socket(&peer_socket);
        return 76 + request_index;
    }

    if (expect_body) {
        if (!deadwire_contains(response_buffer, received, health_body, (int)(sizeof(health_body) - 1))) {
            deadwire_close_client_socket();
            deadwire_close_peer_socket(&peer_socket);
            return 80 + request_index;
        }
    } else if (deadwire_response_has_body(response_buffer, received)) {
        deadwire_close_client_socket();
        deadwire_close_peer_socket(&peer_socket);
        return 85 + request_index;
    }

    if (mode_context[1] != 0 || bound_context[2] != 1 || bound_context[3] != 0 || tick_context[5] != (uint64_t)client_context || tick_context[6] != 0) {
        deadwire_close_client_socket();
        deadwire_close_peer_socket(&peer_socket);
        return 90 + request_index;
    }

    expected_cursor = (uint64_t)((request_index + 1) % DEADWIRE_QUEUE_CAPACITY);
    if (worker_context[4] != (uint64_t)(request_index + 1) || input_queue[0] != expected_cursor || input_queue[1] != expected_cursor || output_queue[0] != expected_cursor || output_queue[1] != expected_cursor) {
        deadwire_close_client_socket();
        deadwire_close_peer_socket(&peer_socket);
        return 100 + request_index;
    }

    deadwire_close_client_socket();
    deadwire_close_peer_socket(&peer_socket);

    if ((SOCKET)client_context[0] != DEADWIRE_SENTINEL_SOCKET || peer_socket != INVALID_SOCKET) {
        return 110 + request_index;
    }

    return 0;
}

static int deadwire_run_bounded_health_loop(struct sockaddr_in *bound_addr) {
    int i;
    int result;

    deadwire_prepare_loop();

    for (i = 0; i < DEADWIRE_SMOKE_REQUESTS; ++i) {
        result = deadwire_run_health_request(bound_addr, i);
        if (result) {
            loop_context[2] = (uint64_t)result;
            return result;
        }
        loop_context[1] = (uint64_t)(i + 1);
    }

    loop_context[2] = 0;
    return 0;
}

static int deadwire_run_long_mode(struct sockaddr_in *server_addr) {
    struct sockaddr_in bound_addr;
    int bound_len = (int)sizeof(bound_addr);
    int result;

    deadwire_prepare_long_mode();

    live_context[0] = 0;
    live_context[1] = (uint64_t)server_addr;
    live_context[2] = sizeof(*server_addr);
    live_context[3] = 1;
    live_context[4] = 99;

    if (dw_runtime_live_open(live_context)) {
        long_context[2] = DEADWIRE_LONG_STOP_ERROR;
        long_context[3] = 2;
        return 2;
    }

    if (getsockname((SOCKET)live_context[0], (struct sockaddr *)&bound_addr, &bound_len)) {
        long_context[2] = DEADWIRE_LONG_STOP_ERROR;
        long_context[3] = 3;
        return deadwire_finish_long_mode(3, 130);
    }

    result = deadwire_run_bounded_health_loop(&bound_addr);
    long_context[1] = loop_context[1];
    if (result) {
        long_context[2] = DEADWIRE_LONG_STOP_ERROR;
        long_context[3] = (uint64_t)result;
        return deadwire_finish_long_mode(result, 131);
    }

    if (loop_context[0] != DEADWIRE_SMOKE_REQUESTS || loop_context[1] != DEADWIRE_SMOKE_REQUESTS || loop_context[2] != 0) {
        long_context[2] = DEADWIRE_LONG_STOP_ERROR;
        long_context[3] = 120;
        return deadwire_finish_long_mode(120, 132);
    }

    long_context[1] = loop_context[1];
    long_context[2] = DEADWIRE_LONG_STOP_TARGET;
    return deadwire_finish_long_mode(0, 133);
}

static int deadwire_v2_live_smoke(void) {
    struct sockaddr_in server_addr;
    int result;

    server_addr.sin_family = AF_INET;
    server_addr.sin_port = 0;
    server_addr.sin_addr.s_addr = 0x0100007f;

    input_queue[0] = 0;
    input_queue[1] = 0;
    input_queue[2] = DEADWIRE_QUEUE_CAPACITY;
    input_queue[3] = (uint64_t)input_items;

    output_queue[0] = 0;
    output_queue[1] = 0;
    output_queue[2] = DEADWIRE_QUEUE_CAPACITY;
    output_queue[3] = (uint64_t)output_items;

    response_context[0] = (uint64_t)health_status;
    response_context[1] = sizeof(health_status) - 1;
    response_context[2] = (uint64_t)health_type;
    response_context[3] = sizeof(health_type) - 1;
    response_context[4] = (uint64_t)health_body;
    response_context[5] = sizeof(health_body) - 1;

    tick_context[0] = (uint64_t)live_context;
    tick_context[1] = (uint64_t)client_context;
    tick_context[2] = (uint64_t)input_queue;
    tick_context[3] = (uint64_t)worker_context;
    tick_context[4] = (uint64_t)output_queue;
    tick_context[5] = 99;
    tick_context[6] = 99;

    bound_context[0] = (uint64_t)tick_context;
    bound_context[1] = 1;
    bound_context[2] = 99;
    bound_context[3] = 99;

    mode_context[0] = (uint64_t)bound_context;
    mode_context[1] = 99;

    deadwire_prepare_tick();
    deadwire_prepare_loop();
    deadwire_prepare_long_mode();

    if (dw_runtime_worker_init(worker_context, 7, input_queue, output_queue)) {
        return 1;
    }

    result = deadwire_run_long_mode(&server_addr);
    if (result) {
        return result;
    }

    if (long_context[0] != DEADWIRE_SMOKE_REQUESTS || long_context[1] != DEADWIRE_SMOKE_REQUESTS || long_context[2] != DEADWIRE_LONG_STOP_TARGET || long_context[3] != 0 || long_context[4] != 0) {
        return 140;
    }

    if (input_queue[0] != 0 || input_queue[1] != 0 || output_queue[0] != 0 || output_queue[1] != 0 || worker_context[4] != DEADWIRE_SMOKE_REQUESTS) {
        return 141;
    }

    if ((SOCKET)client_context[0] != DEADWIRE_SENTINEL_SOCKET || tick_context[5] != (uint64_t)client_context || tick_context[6] != 0) {
        return 142;
    }

    if (live_context[0] != 0 || live_context[4] != 0) {
        return 143;
    }

    return 0;
}

void mainCRTStartup(void) {
    ExitProcess((UINT)deadwire_v2_live_smoke());
}
