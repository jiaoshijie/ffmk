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
#include <errno.h>

#define FFMK_LOG_IMPLEMENTATION
#define FFMK_LOG_FILE_NAME "tool_conv.log"
#include "log.h"

enum FUNC_CODE {
    FC_FILES = 0,
    FC_GREP = 1,
    FC_HELPTAGS = 2,
    FC_CTAGS = 3,
    FC_GNU_GLOBAL = 4,
};

static const char *program_name = "conv";

static void files(char **argv) {
    (void) argv;
    const char *ansi_dir = "\033[3;38:5:248m";  // dir color
    const char *ansi_rm = "\033[9;38:5:196m";  // removed

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
                    is_removed ? ansi_rm : "", name,
                    ansi_dir, is_root ? "/" : path);
        } else {
            fprintf(stdout, "%s%s\033[0m\n",
                    is_removed ? ansi_rm : "", path);  // path is the name
        }
    }
}

static void grep(char **argv) {
    (void) argv;
    const char *sep = "\034";  // \034 \035 \036 \037

    char path[MAX_PATH_LEN] = { 0 }, match[8192] = { 0 };
    char *loc = NULL, *match_data = NULL;
    size_t read_len = 0;

    log_infof("------------ [%s] ------------", __func__);

    while (fgets(path, sizeof(path), stdin)) {
        read_len = strlen(path);
        if (path[read_len - 1] == '\n') path[read_len - 1] = '\0';
        log_infof("parse: %s", path);
        while (fgets(match, sizeof(match), stdin)) {
            if (match[0] == '\n') break;
            read_len = strlen(match);
            if (match[read_len - 1] == '\n') match[read_len - 1] = '\0';
            log_infof("\tparse: %s", match);
            loc = match;
            match_data = strchr(match, ':');
            if (!match_data) log_errorf("match string format error: %s", match);
            match_data = strchr(match, ':');
            if (!match_data) log_errorf("match string format error: %s", match);
            *(match_data++) = '\0';

            fprintf(stdout, "%s%s:%s:%s\n", path, sep, loc, match_data);
        }
    }
}

static void helptags(char **argv) {
    const char *ansi_tag = "\033[3;38:5:182m";
    const char *ansi_fn = "\033[3;38:5:248m";
    const char *sep = "\034";  // \034 \035 \036 \037

    char *tag_path = NULL, tag_dir[MAX_PATH_LEN] = { 0 };
    char item[8192] = { 0 }, *tag, *filename, *pattern;
    char filepath[MAX_PATH_LEN] = { 0 };
    log_infof("------------ [%s] ------------", __func__);
    while (*argv) {
        tag_path = *(argv++);
        if (tag_path[0] != '/') {
            log_infof("Must use absolute path: %s", tag_path);
            continue;
        }

        size_t tag_path_len = strlen(tag_path);
        log_infof("Process %s", tag_path);
        if (tag_path_len >= MAX_PATH_LEN) {
            log_infof("Something should not happen: path length is too big(%d:%s)", tag_path_len, tag_path);
            continue;
        }

        if (access(tag_path, R_OK) != 0) {
            log_infof("tagfile has no read permission: %s", tag_path);
            continue;
        }
        strcpy(tag_dir, tag_path);
        *strrchr(tag_dir, '/') = '\0';  // this is ok, because the first if condition
        if (tag_dir[0] == '\0') {
            log_infof("Whoa, there is a vim helptag file located in root directory, Good for you: %s", tag_path);
            continue;
        }

        FILE *fp = fopen(tag_path, "r");
        if (fp == NULL) {
            log_infof("Open %s file failed: %s", tag_path, strerror(errno));
            continue;
        }

        while(fgets(item, sizeof(item), fp)) {
            size_t item_len = strlen(item);
            if (item[item_len - 1] == '\n') item[item_len - 1] = '\0';

            tag = item;
            filename = strchr(tag, '\t');
            if (filename == NULL) {
                log_infof("Wrong tag item: %s", item);
                continue;
            }
            pattern = strchr(filename + 1, '\t');
            if (pattern == NULL) {
                log_infof("Wrong tag item: %s", item);
                continue;
            }
            *(filename++) = '\0';
            *(pattern++) = '\0';

            if (*pattern == '/') pattern++;

            sprintf(filepath, "%s/%s", tag_dir, filename);
            fprintf(stdout, "%s%s\033[0m%s%s%s%s%s  %s%s\033[0m\n", ansi_tag, tag,
                    sep, filepath, sep, pattern, sep, ansi_fn, filename);
        }

        fclose(fp);
    }
}

static void ctags(char **argv) {
    (void) argv;
    const char *ansi_ty = "\033[3;38:5:248m";  // type color
    const char *sep = "\034";  // \034 \035 \036 \037

    char line[8192] = { 0 }; // if a line is long then this, don't care
    char *symbol = NULL, *type = NULL, *lnum = NULL, *end = NULL;
    size_t read_len = 0;

    log_infof("------------ [%s] ------------", __func__);

    while (fgets(line, sizeof(line), stdin)) {
        read_len = strlen(line);

        if (line[read_len - 1] == '\n') {
            line[read_len - 1] = '\0';
        } else {
            log_infof("get a very long line, started with: %s", line);
            // NOTE: remove that line
            while (fgets(line, sizeof(line), stdin)) {
                read_len = strlen(line);
                if (line[read_len - 1] == '\n') break;
            }
            break;
        }
        log_infof("%s", line);
        symbol = line;
        type = strchr(symbol, ' ');
        if (type == NULL) {
            log_errorf("wrong tag format: %s", symbol);
        }
        *(type++) = '\0';
        while (*type == ' ') type++;
        lnum = strchr(type, ' ');
        if (lnum == NULL) {
            log_errorf("wrong tag format: %s %s", symbol, type);
        }
        *(lnum++) = '\0';
        while (*lnum == ' ') lnum++;
        end = strchr(lnum, ' ');
        if (end == NULL) {
            log_errorf("wrong tag format: %s %s %s", symbol, type, lnum);
        }
        *end = '\0';

        fprintf(stdout, "%s%s%s  %s%s\033[0m\n", lnum, sep, symbol, ansi_ty, type);
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
        grep(argv);
        break;
    case FC_HELPTAGS:
        helptags(argv);
        break;
    case FC_CTAGS:
        ctags(argv);
        break;
    default:
        log_errorf("unknow function code %d", func_code);
    }

    return 0;
}
