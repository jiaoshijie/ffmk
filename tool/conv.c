#ifndef __linux__
#error "Only support linux platform"
#endif

#if !defined(MAX_NAME_LEN) || !defined(MAX_PATH_LEN)
#error "MAX_NAME_LEN or MAX_PATH_LEN not defined"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>

#define FFMK_LOG_IMPLEMENTATION
#define FFMK_LOG_FILE_NAME "tool_conv.log"
#include "log.h"

enum FUNC_CODE {
    FC_INVALID = 0,
    FC_FILES = 1,
    FC_GREP = 2,
    FC_HELPTAGS = 3,
};

static const char *program_name = "conv";

static void files(char **argv) {
    (void) argv;
    const char *ae_d = "\033[3;38:5:248m";  // dir color
    const char *ae_r = "\033[9;38:5:196m";  // removed

    char *name = NULL;
    char path[MAX_PATH_LEN] = { 0 };
    size_t read_len = 0;
    bool is_root = false, is_removed = false;

    log_infof("------------ [%s] ------------", __func__);

    while (fgets(path, sizeof(path), stdin)) {
        read_len = strlen(path);

        if (path[read_len - 1] == '\n') path[read_len - 1] = '\0';
        is_removed = access(path, F_OK) != 0;

        log_infof("%s", path);

        name = strrchr(path, '/');
        if (name) {
            is_root = (uintptr_t)name == (uintptr_t)path;
            *name = '\0';
            name = name + 1;
            if (*name == '\0') continue;
            fprintf(stdout, "%s%s\t%s%s\033[0m\n",
                    is_removed ? ae_r : "", name,
                    ae_d, is_root ? "/" : path);
        } else {
            fprintf(stdout, "%s%s\033[0m\n",
                    is_removed ? ae_r : "", path);  // path is the name
        }
    }
}

int main(int argc, char **argv) {
    (void) argc;
    program_name = *(argv++);
    if (*argv == NULL) {
        log_errorf("Usage: %s func_code", program_name);
    }

    int func_code = strtol(*(argv++), NULL, 10);

    switch (func_code) {
    case FC_FILES:
        files(argv);
        break;
    case FC_GREP:
        log_error("grep not implemented yet!");
        break;
    case FC_HELPTAGS:
        log_error("helptags not implemented yet!");
        break;
    default:
        log_errorf("unknow function code %d", func_code);
    }

    return 0;
}
