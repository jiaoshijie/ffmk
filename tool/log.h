#ifndef FFMK_LOG_H
#define FFMK_LOG_H
#include <stdbool.h>

#ifdef FFMK_DUMP_LOG
#define log_info(msg) \
    impl_print(false, "[INFO] %s:%d: "msg"\n", __FILE__, __LINE__)
#define log_infof(fmt, ...) \
    impl_print(false, "[INFO] %s:%d: "fmt"\n", __FILE__, __LINE__, __VA_ARGS__)
#else
#define log_info(msg)
#define log_infof(fmt, ...)
#endif  // FFMK_DUMP_LOG

#define log_error(msg) \
    impl_print(true, "[ERROR] %s:%d: "msg"\n", __FILE__, __LINE__)
#define log_errorf(fmt, ...) \
    impl_print(true, "[ERROR] %s:%d: "fmt"\n", __FILE__, __LINE__, __VA_ARGS__)

#ifdef FFMK_LOG_IMPLEMENTATION
#ifndef FFMK_LOG_FILE_NAME
#error "FFMK_LOG_FILE_NAME is not defined"
#endif // FFMK_LOG_FILE_NAME

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <time.h>
#include <sys/stat.h>

#define FFMK_LOG_DIR_ENV "FFMK_LOG_DIR"

static FILE *log_fp;

static void log_deinit() {
    if (log_fp) fclose(log_fp);
}

// using the mkdir -p create the log path
// if `mkdir` does not exist, create the log path manually
static void mkdir_p(const char *path) {
    struct stat st;
    char cmd[4096] = { 0 };
    if (stat(path, &st) == 0 && S_ISDIR(st.st_mode)) {
        return;
    }

    snprintf(cmd, sizeof(cmd), "mkdir -p '%s'", path);
    int ret = system(cmd);
    (void) ret;  // discard the compiler warning
}

static bool log_init() {
    if (log_fp) return true;

    char log_path[4096] = { 0 };
    const char *log_dir = getenv(FFMK_LOG_DIR_ENV);
    if (log_dir == NULL) return false;
    mkdir_p(log_dir);
    snprintf(log_path, sizeof(log_path), "%s/%s", log_dir, FFMK_LOG_FILE_NAME);

    log_fp = fopen(log_path, "a");
    if (log_fp == NULL) return false;
    atexit(log_deinit);

    return true;
}

void impl_print(bool is_err, const char *fmt, ...) {
    if (log_fp == NULL && !log_init()) {
        if (is_err) exit(1);
        return;
    }

    time_t t = time(NULL);
    struct tm *tm = localtime(&t);
    if (tm != NULL) {
        fprintf(log_fp, "%d-%02d-%02d %02d:%02d:%02d ", tm->tm_year + 1900,
                tm->tm_mon + 1, tm->tm_mday, tm->tm_hour, tm->tm_min, tm->tm_sec);
    }

    va_list args;
    va_start(args, fmt);
    vfprintf(log_fp, fmt, args);
    va_end(args);

    if (is_err) exit(1);
}
#endif // FFMK_LOG_IMPLEMENTATION
#endif // FFMK_LOG_H
