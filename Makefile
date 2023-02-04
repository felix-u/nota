VERSION=0.3-dev

CFLAGS=-std=c99 -Wall -Wextra -pedantic -Wshadow -Wstrict-overflow \
	   -Wstrict-aliasing
DEBUGFLAGS=-g -ggdb -Og -pg
RELEASEFLAGS=-O3 -s
LIBS=-lm

nota: src/*
	$(CC) $(CFLAGS) $(DEBUGFLAGS) $(LIBS) -o nota src/main.c

release: src/*
	$(CC) $(CFLAGS) $(RELEASEFLAGS) $(LIBS) -o nota src/main.c -march=native

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
