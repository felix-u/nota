CFLAGS=-std=c99 -Wall -pedantic -Werror -Wshadow \
	   -Wstrict-overflow -Wextra -Wall -Wno-unused-but-set-variable -Wno-unused-variable
DEBUGFLAGS=-g -Og
RELEASEFLAGS=-O3 -s

qaml: src/*
	$(CC) $(CFLAGS) $(DEBUGFLAGS) $(LIBS) -o qaml src/main.c

release: src/*
	$(CC) $(CFLAGS) $(RELEASEFLAGS) $(LIBS) -o qaml src/main.c
