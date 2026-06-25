#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#define REQ_CAP 4096
#define PATH_CAP 1024
#define FILE_CAP 65536

static int parse_port(const char *s, unsigned short *out) {
    char *end = NULL;
    long value;

    if (s == NULL || *s == 0) {
        return 0;
    }
    errno = 0;
    value = strtol(s, &end, 10);
    if (errno != 0 || end == s || *end != 0 || value <= 0 || value > 65535) {
        return 0;
    }
    *out = (unsigned short)value;
    return 1;
}

static int parse_bind(const char *s, const char **out) {
    if (s == NULL) {
        return 0;
    }
    if (strcmp(s, "127.0.0.1") == 0 || strcmp(s, "0.0.0.0") == 0) {
        *out = s;
        return 1;
    }
    return 0;
}

static const char *content_type(const char *path) {
    const char *dot = strrchr(path, '.');
    if (dot == NULL) {
        return "text/plain; charset=utf-8";
    }
    if (strcmp(dot, ".html") == 0 || strcmp(dot, ".htm") == 0) {
        return "text/html; charset=utf-8";
    }
    if (strcmp(dot, ".css") == 0) {
        return "text/css; charset=utf-8";
    }
    if (strcmp(dot, ".js") == 0) {
        return "application/javascript; charset=utf-8";
    }
    if (strcmp(dot, ".svg") == 0) {
        return "image/svg+xml; charset=utf-8";
    }
    return "text/plain; charset=utf-8";
}

static int send_all(int fd, const char *buf, size_t len) {
    while (len > 0) {
        ssize_t n = send(fd, buf, len, 0);
        if (n <= 0) {
            return 0;
        }
        buf += n;
        len -= (size_t)n;
    }
    return 1;
}

static void log_line(const char *line) {
    fputs(line, stdout);
    fflush(stdout);
}

static void respond(int fd, int code, const char *reason, const char *type,
                    const char *body, size_t body_len, int head) {
    char header[256];
    int n = snprintf(header, sizeof(header),
                     "HTTP/1.0 %d %s\r\n"
                     "Content-Type: %s\r\n"
                     "Content-Length: %zu\r\n"
                     "Connection: close\r\n"
                     "\r\n",
                     code, reason, type, body_len);
    if (n <= 0 || (size_t)n >= sizeof(header)) {
        return;
    }
    send_all(fd, header, (size_t)n);
    if (!head && body_len > 0) {
        send_all(fd, body, body_len);
    }
}

static void respond_text(int fd, int code, const char *reason, const char *body, int head) {
    respond(fd, code, reason, "text/plain; charset=utf-8", body, strlen(body), head);
}

static int valid_path(const char *path, size_t len, int *too_long) {
    size_t i;

    *too_long = 0;
    if (len == 0 || path[0] != '/') {
        return 0;
    }
    if (len > 500) {
        *too_long = 1;
        return 0;
    }
    for (i = 0; i < len; i++) {
        unsigned char c = (unsigned char)path[i];
        if (c < 32 || c == 127 || c == '\\' || c == '%') {
            return 0;
        }
        if (c == '.' && i + 1 < len && path[i + 1] == '.') {
            return 0;
        }
    }
    return 1;
}

static void serve_file(int fd, const char *path, int head) {
    char fs_path[PATH_CAP];
    char file_buf[FILE_CAP];
    FILE *f;
    long size;
    size_t read_n;

    if (strcmp(path, "/") == 0) {
        snprintf(fs_path, sizeof(fs_path), "public/index.html");
    } else {
        if (snprintf(fs_path, sizeof(fs_path), "public%s", path) >= (int)sizeof(fs_path)) {
            log_line("access status=414 reason=uri-too-long\n");
            respond_text(fd, 414, "URI Too Long", "uri too long\n", head);
            return;
        }
    }

    f = fopen(fs_path, "rb");
    if (f == NULL) {
        log_line("access status=404 reason=not-found\n");
        respond_text(fd, 404, "Not Found", "not found\n", head);
        return;
    }

    if (fseek(f, 0, SEEK_END) != 0) {
        fclose(f);
        log_line("access status=500 reason=file-error\n");
        respond_text(fd, 500, "Internal Server Error", "file error\n", head);
        return;
    }
    size = ftell(f);
    if (size < 0) {
        fclose(f);
        log_line("access status=500 reason=file-error\n");
        respond_text(fd, 500, "Internal Server Error", "file error\n", head);
        return;
    }
    if (size > FILE_CAP) {
        fclose(f);
        log_line("access status=413 reason=too-large\n");
        respond_text(fd, 413, "Payload Too Large", "file too large\n", head);
        return;
    }
    rewind(f);
    read_n = fread(file_buf, 1, (size_t)size, f);
    fclose(f);
    if (read_n != (size_t)size) {
        log_line("access status=500 reason=file-error\n");
        respond_text(fd, 500, "Internal Server Error", "file error\n", head);
        return;
    }

    log_line("access status=200 route=static\n");
    respond(fd, 200, "OK", content_type(fs_path), file_buf, read_n, head);
}

static void handle_client(int fd) {
    char req[REQ_CAP + 1];
    ssize_t n;
    char *method;
    char *path;
    char *path_end;
    size_t method_len;
    size_t path_len;
    int head = 0;
    int too_long = 0;

    n = recv(fd, req, REQ_CAP, 0);
    if (n <= 0) {
        return;
    }
    req[n] = 0;

    method = req;
    path = strchr(req, ' ');
    if (path == NULL) {
        log_line("access status=400 reason=bad-request\n");
        respond_text(fd, 400, "Bad Request", "bad request\n", 0);
        return;
    }
    method_len = (size_t)(path - method);
    path++;

    if (method_len == 3 && memcmp(method, "GET", 3) == 0) {
        head = 0;
    } else if (method_len == 4 && memcmp(method, "HEAD", 4) == 0) {
        head = 1;
    } else {
        log_line("access status=405 reason=method\n");
        respond_text(fd, 405, "Method Not Allowed", "method not allowed\n", 0);
        return;
    }

    path_end = strchr(path, ' ');
    if (path_end == NULL) {
        log_line("access status=400 reason=bad-request\n");
        respond_text(fd, 400, "Bad Request", "bad request\n", head);
        return;
    }
    *path_end = 0;
    path_len = strlen(path);

    if (!valid_path(path, path_len, &too_long)) {
        if (too_long) {
            log_line("access status=414 reason=uri-too-long\n");
            respond_text(fd, 414, "URI Too Long", "uri too long\n", head);
        } else {
            log_line("access status=403 reason=forbidden\n");
            respond_text(fd, 403, "Forbidden", "forbidden\n", head);
        }
        return;
    }

    if (strcmp(path, "/health") == 0) {
        log_line("access status=200 route=/health\n");
        respond_text(fd, 200, "OK", "deadwire: ok\n", head);
        return;
    }

    serve_file(fd, path, head);
}

int main(int argc, char **argv) {
    unsigned short port = 18080;
    const char *bind_addr = "127.0.0.1";
    int server_fd;
    int yes = 1;
    struct sockaddr_in addr;

    signal(SIGPIPE, SIG_IGN);

    if (argc > 3) {
        fputs("fatal: bad arg\n", stdout);
        return 1;
    }
    if (argc >= 2 && !parse_port(argv[1], &port)) {
        fputs("fatal: bad arg\n", stdout);
        return 1;
    }
    if (argc == 3 && !parse_bind(argv[2], &bind_addr)) {
        fputs("fatal: bad arg\n", stdout);
        return 1;
    }

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        fputs("fatal: socket failed\n", stdout);
        return 1;
    }
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    if (inet_pton(AF_INET, bind_addr, &addr.sin_addr) != 1) {
        close(server_fd);
        fputs("fatal: bad arg\n", stdout);
        return 1;
    }

    if (bind(server_fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(server_fd);
        fputs("fatal: bind failed; address unavailable\n", stdout);
        return 1;
    }
    if (listen(server_fd, 16) != 0) {
        close(server_fd);
        fputs("fatal: listen failed\n", stdout);
        return 1;
    }

    printf("DEADWIRE HTTPD v1.0.0 DARWIN\nlistening on http://%s:%u\n", bind_addr, (unsigned)port);
    fflush(stdout);

    for (;;) {
        int client_fd = accept(server_fd, NULL, NULL);
        if (client_fd < 0) {
            continue;
        }
        handle_client(client_fd);
        close(client_fd);
    }
}
