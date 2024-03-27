#ifndef BASE
#define BASE

#define _CRT_SECURE_NO_WARNINGS

#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef   uint8_t    u8;
typedef  uint16_t   u16;
typedef  uint32_t   u32;
typedef  uint64_t   u64;
typedef    int8_t    i8;
typedef   int16_t   i16;
typedef   int32_t   i32;
typedef   int64_t   i64;
typedef     float   f32;
typedef    double   f64;

typedef unsigned char uchar;
typedef        size_t usize;
typedef     uintptr_t  uptr;
typedef      intptr_t  iptr;

// static void err_accumulation_begin(void);
// static void err(Str8 error);
// static void errf(char *fmt, ...);
// static Str8 err_accumulation_end(Arena *arena);
//
// typedef struct Error_Node {
//     struct Error_Node *next;
//     usize pos;
//     Str8 error;
// } Error_Node;
//
// typedef struct Error_Info {
//     Arena *arena;
//     Error_Node *stack;
// } Error_Info;

#define err(s) _err(__FILE__, __LINE__, __func__, s)
static void _err(char *file, usize line, const char *func, char *s) {
    fprintf(stderr, "error: %s\n", s);
    #ifdef DEBUG
        fprintf(
            stderr, 
            "%s:%zu:%s(): error first returned here\n", 
            file, line, func
        );
    #else
        (void)file;
        (void)line;
        (void)func;
    #endif // DEBUG
}

#define errf(fmt, ...) _errf(__FILE__, __LINE__, __func__, fmt, __VA_ARGS__)
static void _errf(char *file, usize line, const char *func, char *fmt, ...) {
    fprintf(stderr, "error: ");
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fprintf(stderr, "\n");
    #ifdef DEBUG
        fprintf(
            stderr, 
            "%s:%zu:%s(): error first returned here\n", 
            file, line, func
        );
    #else
        (void)file;
        (void)line;
        (void)func;
    #endif // DEBUG
}

#define Array(type) struct { type *ptr; usize len; usize cap; }
typedef Array(void) Array_Memory;

typedef struct Arena {
    void *mem;
    usize offset;
    usize cap;
    usize last_offset;
} Arena;

static Arena arena_init(usize size) {
    Arena arena = {0};
    arena.mem = calloc(1, size);
    if (arena.mem == 0) err("allocation failure");
    arena.cap = size; 
    return arena;
}

static void arena_align(Arena *arena, usize align) {
    usize modulo = arena->offset & (align - 1);
    if (modulo != 0) arena->offset += align - modulo;
}

#define ARENA_DEFAULT_ALIGNMENT (2 * sizeof(void *))
static Array_Memory arena_alloc(Arena *arena, usize size) {
    Array_Memory memory = {0};
    arena_align(arena, ARENA_DEFAULT_ALIGNMENT);
    if (arena->offset + size >= arena->cap) {
        err("allocation failure");
        return memory;
    }
    memory.ptr = (u8 *)arena->mem + arena->offset;
    memory.cap = size;
    arena->last_offset = arena->offset;
    arena->offset += size;
    return memory;
}

static void arena_deinit(Arena *arena) {
    free(arena->mem);
    arena->offset = 0;
    arena->cap = 0;
}

#define count_of(arr) (sizeof(arr) / sizeof((arr)[0]))

#define Slice(type) struct { type *ptr; usize len; }
#define slice(arr) { .ptr = arr, .len = count_of(arr) }
#define slice_expand(s) (s).ptr, (s).len
#define slice_push(slice, item) (slice).ptr[(slice).len++] = (item)
#define slice_pop(slice) (slice).ptr[--(slice).len]

typedef Slice(u8) Str8;
typedef Slice(Str8) Slice_Str8;
#define str8(s) (Str8){ .ptr = (u8 *)s, .len = sizeof(s) - 1 }
#define str8_fmt(s) (int)(s).len, (s).ptr

static bool str8_eql(Str8 s1, Str8 s2) {
    if (s1.len != s2.len) return false;
    for (usize i = 0; i < s1.len; i += 1) {
        if (s1.ptr[i] != s2.ptr[i]) return false;
    }
    return true;
}

static Str8 str8_from_cstr(char *s) {
    if (s == NULL) return (Str8){ 0 };
    usize len = 0;
    while (s[len] != '\0') len += 1;
    return (Str8){ .ptr = (u8 *)s, .len = len };
}

static char *cstr_from_str8(Arena *arena, Str8 s) {
    char *cstr = arena_alloc(arena, s.len + 1).ptr;
    for (usize i = 0; i < s.len; i += 1) cstr[i] = s.ptr[i];
    cstr[s.len] = '\0';
    return cstr;
}

// Only bases <= 10
static Str8 str8_from_int_base(Arena *arena, usize _num, u8 base) {
    Str8 str = {0};
    usize num = _num;

    do {
        num /= base;
        str.len += 1;
    } while (num > 0);
    
    str.ptr = arena_alloc(arena, str.len).ptr;

    num = _num;
    for (i64 i = str.len - 1; i >= 0; i -= 1) {
        str.ptr[i] = (num % base) + '0';
        num /= base;
    }

    return str;
}

static Str8 str8_range(Str8 s, usize beg, usize end) {
    return (Str8){
        .ptr = s.ptr + beg,
        .len = end - beg,
    };
}

const u8 decimal_from_hex_char_table[256] = {
    ['0'] = 0, ['1'] = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4, 
    ['5'] = 5, ['6'] = 6, ['7'] = 7, ['8'] = 8, ['9'] = 9, 
    ['A'] = 10, ['B'] = 11, ['C'] = 12, ['D'] = 13, ['E'] = 14, ['F'] = 15,
    ['a'] = 10, ['b'] = 11, ['c'] = 12, ['d'] = 13, ['e'] = 14, ['f'] = 15,
};

static usize decimal_from_hex_str8(Str8 s) {
    usize result = 0, magnitude = s.len;
    for (usize i = 0; i < s.len; i += 1, magnitude -= 1) {
        usize hex_digit = decimal_from_hex_char_table[s.ptr[i]];
        for (usize j = 1; j < magnitude; j += 1) hex_digit *= 16;
        result += hex_digit;
    }
    return result;
}

static FILE *file_open(Str8 path, char *mode) {
    if (path.len == 0 || mode == 0) return 0;
    FILE *file = fopen((char *)path.ptr, mode);
    if (file == 0) errf("failed to open file '%.*s'", str8_fmt(path));
    return file;
}

static Str8 file_read(Arena *arena, Str8 path, char *mode) {
    Str8 bytes = {0};
    if (path.len == 0 || mode == 0) return bytes;

    FILE *file = file_open(path, mode);
    
    fseek(file, 0L, SEEK_END);
    usize filesize = ftell(file);
    bytes.ptr = arena_alloc(arena, filesize + 1).ptr;

    fseek(file, 0L, SEEK_SET);
    bytes.len = fread(bytes.ptr, sizeof(u8), filesize, file);
    bytes.ptr[bytes.len] = '\0';

    if (ferror(file)) {
        fclose(file);
        errf("error reading file '%.*s'", str8_fmt(path));
        return (Str8){0};
    }

    fclose(file);
    return bytes;
}

static void file_write(FILE *file, Str8 memory) {
    fwrite(memory.ptr, memory.len, 1, file);
}

#define min(a, b) ((a) < (b)) ? (b) : (a)
#define max(a, b) ((a) > (b)) ? (b) : (a)
#define clamp(x, _min, _max) {\
    x = min((_min), (x));\
    x = max((_max), (x));\
}

#endif // BASE
