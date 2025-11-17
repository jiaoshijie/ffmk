#ifndef __linux__
#error "Only support linux platform"
#endif

// https://github.com/msgpack-rpc/msgpack-rpc/blob/master/spec.md
// https://github.com/msgpack/msgpack/blob/0b8f5ac/spec.md

/*
 * A simple msgpack-rpc client for `nvim_exec_lua`
 * */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include <linux/un.h>
#include <errno.h>
#include <sys/socket.h>
#include <unistd.h>

#define PACKET_RECV_BUF_LEN 2048
#define SOCKET_TIMEOUT_US 100 * 1000  // 100ms

#define FFMK_SOCK_PATH_ENV "FFMK_RPC_UNIX_SOCKET"
#define SEND_MSGID 0x01  // I think this is ok, because each process only send once

#define NVIM_METHOD "nvim_exec_lua"
#define NVIM_METHOD_CODE "require('ffmk.rpc').call({ ... })"

#define FFMK_LOG_IMPLEMENTATION
#define FFMK_LOG_FILE_NAME "tool_rpc_client.log"
#include "log.h"

static const char *program_name = "rpc_client";
static const char *g_sock_path = NULL;

enum FUNC_CODE {
    FC_QUIT             = 0,
    FC_QUERY            = 1,
    FC_FILES_ENTER      = 2,
    FC_FILES_PREVIEW    = 3,
    FC_GREP_ENTER       = 4,
    FC_GREP_SEND2QF     = 5,
    FC_GREP_SEND2LL     = 6,
    FC_GREP_PREVIEW     = 7,
    FC_HELPTAGS_ENTER   = 8,
    FC_HELPTAGS_PREVIEW = 9,
    FC_MAX,
};
_Static_assert(FC_MAX < 256, "Whoa! So Many Function Code Here!!!");

static struct packet_vec {
    uint8_t *buf;
    size_t len;
    size_t cap;
} g_pv;

static void packet_vec_clear() {
    free(g_pv.buf);
    g_pv.buf = NULL;
    g_pv.len = 0;
    g_pv.cap = 0;
}

static void packet_vec_append(const uint8_t *buf, size_t len) {
    if (g_pv.len + len > g_pv.cap) {
        size_t new_cap = g_pv.cap == 0 ? 1024 : g_pv.cap * 2;
        uint8_t *new_buf = (uint8_t *)realloc(g_pv.buf, new_cap);
        if (new_buf) {
            g_pv.buf = new_buf;
            g_pv.cap = new_cap;
        } else {
            log_error("malloc packet failed");
        }
    }
    memcpy(g_pv.buf + g_pv.len, buf, len);
    g_pv.len += len;
}

static void packet_vec_append_byte(uint8_t byte)  {
    packet_vec_append(&byte, 1);
}

static void packet_vec_append_str_header(size_t len) {
    if (len <= 0xbf - 0xa0) {
        packet_vec_append_byte(0xa0 + len);
    } else if (len <= 0xff) {
        packet_vec_append_byte(0xd9);
        packet_vec_append_byte((uint8_t)len);
    } else if (len <= 0xffff) {
        uint16_t buf = htons((uint16_t)len);
        packet_vec_append_byte(0xda);
        packet_vec_append((void *)&buf, sizeof(buf));
    } else if (len <= 0xffffffff) {
        uint32_t buf = htonl((uint32_t)len);
        packet_vec_append_byte(0xdb);
        packet_vec_append((void *)&buf, sizeof(buf));
    } else {
        log_error("unreachable!!!");
    }
}

static void packet_vec_append_arr_header(size_t len) {
    if (len <= 0x9f - 0x90) {
        packet_vec_append_byte(0x90 + len);
    } else if (len <= 0xffff) {
        uint16_t buf = htons((uint16_t)len);
        packet_vec_append_byte(0xdc);
        packet_vec_append((void *)&buf, sizeof(buf));
    } else if (len <= 0xffffffff) {
        uint32_t buf = htonl((uint32_t)len);
        packet_vec_append_byte(0xdd);
        packet_vec_append((void *)&buf, sizeof(buf));
    } else {
        log_error("unreachable!!!");
    }
}

// only dump at most PACKET_RECV_BUF_LEN byte
static const char *hexdump_packet(uint8_t *buf, size_t len) {
    static char dump_buf[PACKET_RECV_BUF_LEN * 2] = { 0 };

    for (size_t i = 0; i < len; i++) {
        sprintf(dump_buf + i * 2, "%02x", buf[i]);
    }

    return (const char*)dump_buf;
}

static bool check_success(uint8_t *buf, size_t len) {
    uint8_t success_msg[] = {
        [0] = 0x94,
        [1] = 0x01,
        [2] = SEND_MSGID,
        [3] = 0xc0,
        [4] = 0xc0,
    };

    if (len != sizeof(success_msg) / sizeof(success_msg[0])) return false;

    return memcmp(success_msg, buf, len) == 0;
}

static void send2nvim() {
    struct sockaddr_un addr = { 0 };
    struct timeval timeout = {
        .tv_usec = SOCKET_TIMEOUT_US,
    };
    uint8_t buf[PACKET_RECV_BUF_LEN] = { 0 };

    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock == -1) {
        log_errorf("open socket failed: %s", strerror(errno));
    }

    if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) < 0) {
        close(sock);
        log_errorf("set socket timeout failed: %s", strerror(errno));
    }

    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, g_sock_path, sizeof(addr.sun_path) - 1);

    // Connect to the server socket
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        close(sock);
        log_errorf("connect to nvim failed: %s", strerror(errno));
    }

    ssize_t len = send(sock, g_pv.buf, g_pv.len, 0);
    if ((size_t)len != g_pv.len) {
        close(sock);
        log_errorf("send to nvim failed: %s", strerror(errno));
    }

    len = recv(sock, buf, sizeof(buf), 0);
    close(sock);

    if (len < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            log_error("recv socket timed out!");
        } else {
            log_errorf("recv socket error: %s", strerror(errno));
        }
    } else if (len == 0) {
        log_error("peer shutdown the socket");
    } else if (!check_success(buf, len)) {
        log_errorf("request failed: %s", hexdump_packet(buf, len));
    }
}

// 0x94 fixarray [type, msgid, method, params]
//   0x00  type -- request msg
//   0x01  msgid -- I think always be 1 is ok
//   0xad "nvim_exec_lua"  method
//   0x92 params -- fixarray [code args]
//     {len} {code} str type  -- code
//     array type -- args if there is no argument to pass using 0x90
//       args

static void rpc_request(int argc, char **argv, int func_code) {
    size_t len = 0;
    const char *arg = NULL;

    // 1. pack the msgpack-rpc msg
    packet_vec_append_arr_header(4);
    packet_vec_append_byte(0x00);
    packet_vec_append_byte(SEND_MSGID);
    len = strlen(NVIM_METHOD);
    packet_vec_append_str_header(len);
    packet_vec_append((void *)NVIM_METHOD, len);
    packet_vec_append_arr_header(2);
    len = strlen(NVIM_METHOD_CODE);
    packet_vec_append_str_header(len);
    packet_vec_append((void *)NVIM_METHOD_CODE, len);
    packet_vec_append_arr_header(argc + 1);  // 1 extra function code
    packet_vec_append_byte((uint8_t)func_code);  // function code

    log_infof("----------------- %s[%d] -----------------", __func__, func_code);
    while ((arg = *(argv++)) != NULL) {
        len = strlen(arg);
        packet_vec_append_str_header(len);
        packet_vec_append((void *)arg, len);
        log_infof("arg: '%s'", arg);
    }
    log_infof("request hexdump: %s", hexdump_packet(g_pv.buf, g_pv.len));

    send2nvim();
}

// cmd argument: function_code {}/{+} {q} {n}
int main(int argc, char **argv) {
    program_name = *(argv++);
    argc -= 1;
    if (*argv == NULL) {
        log_errorf("Usage: %s func_code", program_name);
    }
    g_sock_path = getenv(FFMK_SOCK_PATH_ENV);
    if (g_sock_path == NULL) {
        log_error("get socket path from env failed");
    }

    int func_code = strtol(*(argv++), NULL, 10);
    argc -= 1;

    atexit(packet_vec_clear);

    log_infof("receive function code: %d", func_code);
    switch (func_code) {
    case FC_QUIT:
    case FC_QUERY:
    case FC_FILES_ENTER:
    case FC_FILES_PREVIEW:
        rpc_request(argc, argv, func_code);
        break;
    default:
        log_errorf("unknow function code %d", func_code);
    }

    return 0;
}
