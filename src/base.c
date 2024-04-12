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

#define discard(expression) (void)(expression)

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

typedef struct Arena {
    void *mem;
    usize offset;
    usize cap;
    usize last_offset;
} Arena;

#define count_of(arr) (sizeof(arr) / sizeof((arr)[0]))

static inline usize _next_power_of_2(usize n) {
    usize result = 1;
    while (result < n) result *= 2;
    return result;
}

static Arena arena_init(usize size) {
    Arena arena = { .mem = calloc(1, size) };
    if (arena.mem == 0) err("allocation failure");
    else arena.cap = size; 
    return arena;
}

static void arena_align(Arena *arena, usize align) {
    usize modulo = arena->offset & (align - 1);
    if (modulo != 0) arena->offset += align - modulo;
}

#define ARENA_DEFAULT_ALIGNMENT (2 * sizeof(void *))
static void *arena_alloc(Arena *arena, usize cap, usize sizeof_elem) {
    usize size = cap * sizeof_elem;
    arena_align(arena, ARENA_DEFAULT_ALIGNMENT);
    if (arena->offset + size >= arena->cap) {
        err("allocation failure");
        return 0;
    }

    void *mem = (u8 *)arena->mem + arena->offset;
    arena->last_offset = arena->offset;
    arena->offset += size;
    return mem;
}

static void *
arena_realloc(Arena *arena, void *mem, usize cap, usize sizeof_elem) {
    usize size = cap * sizeof_elem;
    void *last_allocation = (u8 *)arena->mem + arena->last_offset;
    if (mem == last_allocation && arena->last_offset + size <= arena->cap) {
        arena->offset = arena->last_offset + size;
        return mem;
    }
    return arena_alloc(arena, cap, sizeof_elem);
}

#define Array(type) struct { type *ptr; usize len, cap; }
typedef Array(void) Array_void;

#define arena_alloc_array(arena_ptr, array_ptr, cap) \
    _arena_alloc_array(\
        arena_ptr,\
        (Array_void *)(array_ptr),\
        cap,\
        sizeof(*((array_ptr)->ptr))\
    )
static void _arena_alloc_array(
    Arena *arena, Array_void *array, usize cap, usize sizeof_elem
) {
    array->ptr = arena_alloc(arena, cap, sizeof_elem);
    array->len = 0;
    array->cap = (array->ptr == 0) ? 0 : cap;
}

#define arena_realloc_array(arena_ptr, array_ptr, cap) \
    _arena_realloc_array(\
        arena_ptr,\
        (Array_void *)(array_ptr),\
        cap,\
        sizeof(*((array_ptr)->ptr))\
    )
static void _arena_realloc_array(
    Arena *arena, Array_void *array, usize cap, usize sizeof_elem
) {
    void *old_ptr = array->ptr;
    array->ptr = arena_realloc(arena, array->ptr, cap, sizeof_elem);
    if (array->ptr == 0) {
        *array = (Array_void){0};
        return;
    }
    // memmove instead of memcpy because there is overlap (the ranges are 
    // identical) if arena_realloc() didn't need to really realloc
    memmove(array->ptr, old_ptr, array->len * sizeof_elem);
    array->cap = cap;
}

static void arena_deinit(Arena *arena) {
    free(arena->mem);
    arena->offset = 0;
    arena->cap = 0;
}

#define array_push_array(arena_ptr, base_ptr, push_ptr) \
    _array_push_array(\
        arena_ptr,\
        (Array_void *)base_ptr,\
        (Array_void *)push_ptr,\
        sizeof(*((base_ptr)->ptr))\
    )
static void _array_push_array(
    Arena *arena, Array_void *base, Array_void *push, usize sizeof_elem
) {
    usize new_len = base->len + push->len;
    if (new_len >= base->cap) {
        usize new_cap = _next_power_of_2(new_len);
        _arena_realloc_array(arena, base, new_cap, sizeof_elem);
        if (base->cap == 0) return;
    }
    memmove(
        (u8 *)base->ptr + (base->len * sizeof_elem), 
        push->ptr, 
        push->len * sizeof_elem
    );
    base->len = new_len;
}

#define array_push(arena_ptr, array_ptr, item_ptr) \
    _array_push(\
        arena_ptr, (Array_void *)(array_ptr), item_ptr, sizeof(*(item_ptr))\
    )
static inline void 
_array_push(Arena *arena, Array_void *array, void *item, usize sizeof_elem) {
    Array_void push = { .ptr = item, .len = 1, .cap = 1 };
    _array_push_array(arena, array, &push, sizeof_elem);
}

#define Slice(type) struct { type *ptr; usize len; }
#define slice(c_array) { .ptr = c_array, .len = count_of(c_array) }
#define slice_c_array(c_array) { .ptr = c_array, .len = count_of(c_array) }
#define slice_push(slice, item) (slice).ptr[(slice).len++] = item

typedef struct { u8 *ptr; usize len; } Str8;
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
    char *cstr = arena_alloc(arena, s.len + 1, sizeof(char));
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
    
    str.ptr = arena_alloc(arena, str.len, sizeof(u8));

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

static FILE *file_open(char *path, char *mode) {
    if (path == 0 || mode == 0) return 0;
    FILE *file = fopen(path, mode);
    if (file == 0) errf("failed to open file '%s'", path);
    return file;
}

static Str8 file_read(Arena *arena, char *path, char *mode) {
    Str8 bytes = {0};
    if (path == 0 || mode == 0) return bytes;

    FILE *file = file_open(path, mode);
    
    fseek(file, 0L, SEEK_END);
    usize filesize = ftell(file);
    bytes.ptr = arena_alloc(arena, filesize + 1, sizeof(u8));

    fseek(file, 0L, SEEK_SET);
    bytes.len = fread(bytes.ptr, sizeof(u8), filesize, file);
    bytes.ptr[bytes.len] = '\0';

    if (ferror(file)) {
        fclose(file);
        errf("error reading file '%s'", path);
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
