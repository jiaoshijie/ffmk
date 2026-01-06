MAX_FILENAME_LEN := $(shell getconf NAME_MAX $(HOME))
MAX_PATH_LEN := $(shell getconf PATH_MAX $(HOME))
CC := gcc
CPPFLAGS += -DMAX_NAME_LEN=$(MAX_FILENAME_LEN) -DMAX_PATH_LEN=$(MAX_PATH_LEN)
CFLAGS += -Wall -Wextra -O3

.PHONY: check_length help

tool: bin/conv bin/rpc_client

help:
	@echo -e 'Usage:'
	@echo -e '\t`make -B`: only report error message'
	@echo -e '\t`CPPFLAGS="-DFFMK_DUMP_LOG" make -B`: dump all messages'

check_length:
	@echo "The maximum file name length is $(MAX_FILENAME_LEN)"
	@echo "The maximum path length is $(MAX_PATH_LEN)"

bin/conv: tool/conv.o
	@mkdir -p ./bin
	$(CC) -o $@ $^
	strip $@

bin/rpc_client: tool/rpc_client.o
	@mkdir -p ./bin
	$(CC) -o $@ $^
	strip $@

# gcc -MM conv.c
tool/rpc_client.o: tool/rpc_client.c tool/log.h
tool/conv.o: tool/conv.c tool/log.h
