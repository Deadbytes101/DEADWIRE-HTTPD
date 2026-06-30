#include <stdint.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

extern int dw_runtime_worker_init(uint64_t *worker, uint64_t id, uint64_t *input_queue, uint64_t *output_queue);
extern int dw_runtime_live_open(uint64_t *live_context);
extern int dw_runtime_live_close(uint64_t *live_context);
extern int dw_runtime_mode_bound(uint64_t *mode_context);

static uint64_t input_items[4];
static uint64_t output_items[4];
static uint64_t input_queue[4];
static uint64_t output_queue[4];
static uint64_t worker_context[5];
static uint64_t live_context[5];
static uint64_t client_context[4];
static uint64_t tick_context[7];
static uint64_t bound_context[4];
static uint64_t mode_context[2];
static uint64_t response_context[6];
static char request_buffer[512];
static char response_buffer[1024];

static const char smoke_request[] = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n";
static const char smoke_status[] = "HTTP/1.1 200 OK\r\n";
static const char smoke_type[] = "text/plain";
static const char smoke_body[] = "V2 RUNTIME OK";

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

static int deadwire_v2_live_smoke(void) {
    struct sockaddr_in server_addr;
    struct sockaddr_in bound_addr;
    int bound_len = (int)sizeof(bound_addr);
    SOCKET peer_socket = INVALID_SOCKET;
    int received;

    server_addr.sin_family = AF_INET;
    server_addr.sin_port = 0;
    server_addr.sin_addr.s_addr = 0x0100007f;

    input_queue[0] = 0;
    input_queue[1] = 0;
    input_queue[2] = 4;
    input_queue[3] = (uint64_t)input_items;

    output_queue[0] = 0;
    output_queue[1] = 0;
    output_queue[2] = 4;
    output_queue[3] = (uint64_t)output_items;

    response_context[0] = (uint64_t)smoke_status;
    response_context[1] = sizeof(smoke_status) - 1;
    response_context[2] = (uint64_t)smoke_type;
    response_context[3] = sizeof(smoke_type) - 1;
    response_context[4] = (uint64_t)smoke_body;
    response_context[5] = sizeof(smoke_body) - 1;

    live_context[0] = 0;
    live_context[1] = (uint64_t)&server_addr;
    live_context[2] = sizeof(server_addr);
    live_context[3] = 1;
    live_context[4] = 99;

    client_context[0] = 99;
    client_context[1] = (uint64_t)request_buffer;
    client_context[2] = sizeof(request_buffer);
    client_context[3] = (uint64_t)response_context;

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

    if (dw_runtime_worker_init(worker_context, 7, input_queue, output_queue)) {
        return 1;
    }

    if (dw_runtime_live_open(live_context)) {
        return 2;
    }

    if (getsockname((SOCKET)live_context[0], (struct sockaddr *)&bound_addr, &bound_len)) {
        dw_runtime_live_close(live_context);
        return 3;
    }

    peer_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (peer_socket == INVALID_SOCKET) {
        dw_runtime_live_close(live_context);
        return 4;
    }

    if (connect(peer_socket, (struct sockaddr *)&bound_addr, sizeof(bound_addr))) {
        closesocket(peer_socket);
        dw_runtime_live_close(live_context);
        return 5;
    }

    if (send(peer_socket, smoke_request, (int)(sizeof(smoke_request) - 1), 0) != (int)(sizeof(smoke_request) - 1)) {
        closesocket(peer_socket);
        dw_runtime_live_close(live_context);
        return 6;
    }

    if (dw_runtime_mode_bound(mode_context)) {
        closesocket(peer_socket);
        dw_runtime_live_close(live_context);
        return 7;
    }

    received = recv(peer_socket, response_buffer, (int)(sizeof(response_buffer) - 1), 0);
    if (received <= 0) {
        closesocket((SOCKET)client_context[0]);
        closesocket(peer_socket);
        dw_runtime_live_close(live_context);
        return 8;
    }
    response_buffer[received] = 0;

    if (!deadwire_contains(response_buffer, received, smoke_status, (int)(sizeof(smoke_status) - 1))) {
        closesocket((SOCKET)client_context[0]);
        closesocket(peer_socket);
        dw_runtime_live_close(live_context);
        return 9;
    }

    if (!deadwire_contains(response_buffer, received, smoke_body, (int)(sizeof(smoke_body) - 1))) {
        closesocket((SOCKET)client_context[0]);
        closesocket(peer_socket);
        dw_runtime_live_close(live_context);
        return 10;
    }

    if (worker_context[4] != 1 || input_queue[0] != 1 || input_queue[1] != 1 || output_queue[0] != 1 || output_queue[1] != 1) {
        closesocket((SOCKET)client_context[0]);
        closesocket(peer_socket);
        dw_runtime_live_close(live_context);
        return 11;
    }

    closesocket((SOCKET)client_context[0]);
    closesocket(peer_socket);

    if (dw_runtime_live_close(live_context)) {
        return 12;
    }

    return 0;
}

void mainCRTStartup(void) {
    ExitProcess((UINT)deadwire_v2_live_smoke());
}
