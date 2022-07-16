.PHONY: all install uninstall test build debug static test_all test_mt
PREFIX ?= /usr

all: build

debug:
	shards build

build:
	shards build --production --no-debug --release -Dpreview_mt
	
static:
	shards build --production --no-debug --release -Dpreview_mt --static

test_all: test test_mt

test:
	crystal spec --order random

test_mt:
	crystal spec --order random -Dpreview_mt 

install:
	install -D -m 0755 bin/sabo-tabby $(PREFIX)/bin/sabo-tabby

uninstall:
	rm -f $(PREFIX)/bin/sabo-tabby
