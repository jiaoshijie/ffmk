V := @
MAX_FILENAME_LEN := $(shell getconf NAME_MAX $(HOME))
MAX_PATH_LEN := $(shell getconf PATH_MAX $(HOME))
CFLAGS += -Wall -Wextra -O3

.PHONY: check_length help

tool: bin/conv bin/rpc_client

help:
	$(V)echo -e 'Usage:'
	$(V)echo -e '\t`make -B`: only report error message'
	$(V)echo -e '\t`CFLAGS="-DFFMK_DUMP_LOG" make -B`: dump all messages'

check_length:
	$(V)echo "The maximum file name length is $(MAX_FILENAME_LEN)"
	$(V)echo "The maximum path length is $(MAX_PATH_LEN)"

bin/conv: ./tool/conv.c ./tool/log.h
	$(V)mkdir -p ./bin
	cc -o $@ $^ $(CFLAGS) -DMAX_NAME_LEN=$(MAX_FILENAME_LEN) -DMAX_PATH_LEN=$(MAX_PATH_LEN)
	$(V)strip $@

bin/rpc_client: ./tool/rpc_client.c ./tool/log.h
	$(V)mkdir -p ./bin
	cc -o $@  $^ $(CFLAGS)
	$(V)strip $@
