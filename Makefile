VERSION=0.1

CFLAGS=-std=c99 -Wall -pedantic -Werror -Wshadow -Wstrict-overflow -Wextra \
	   -Wall -Wno-unused-variable
DEBUGFLAGS=-g -Og
RELEASEFLAGS=-O3 -s
LIBS=-lm

nota: src/*
	$(CC) $(CFLAGS) $(DEBUGFLAGS) $(LIBS) -o nota src/main.c

release: src/*
	$(CC) $(CFLAGS) $(RELEASEFLAGS) $(LIBS) -o nota src/main.c

cross: src/*
	mkdir -p release
	zig cc -static -target x86_64-windows     $(CFLAGS) $(RELEASEFLAGS) $(LIBS) -o release/nota-v$(VERSION)-x86_64-win.exe  src/main.c
	zig cc -static -target aarch64-windows    $(CFLAGS) $(RELEASEFLAGS) $(LIBS) -o release/nota-v$(VERSION)-aarch64-win.exe src/main.c
	zig cc -static -target x86_64-linux-musl  $(CFLAGS) $(RELEASEFLAGS) $(LIBS) -o release/nota-v$(VERSION)-x86_64-linux    src/main.c
	zig cc -static -target aarch64-linux-musl $(CFLAGS) $(RELEASEFLAGS) $(LIBS) -o release/nota-v$(VERSION)-aarch64-linux   src/main.c
	zig cc -static -target x86_64-macos       $(CFLAGS) $(RELEASEFLAGS) $(LIBS) -o release/nota-v$(VERSION)-x86_64-macos    src/main.c
	zig cc -static -target aarch64-macos      $(CFLAGS) $(RELEASEFLAGS) $(LIBS) -o release/nota-v$(VERSION)-aarch64-macos   src/main.c

copy:
	cp nota ~/.local/bin/

install: release copy
