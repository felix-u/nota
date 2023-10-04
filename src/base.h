// 2023-10-02
#ifndef BASE_H
#define BASE_H

#include <stdbool.h>

#include <stddef.h>
#include <stdint.h>

typedef   uint8_t    u8;
typedef  uint16_t   u16;
typedef  uint32_t   u32;
typedef  uint64_t   u64;
typedef    int8_t    i8;
typedef   int16_t   i16;
typedef   int32_t   i32;
typedef   int64_t   i64;
typedef    size_t usize;
typedef uintptr_t  uptr;
typedef  intptr_t  iptr;
typedef     float   f32;
typedef    double   f64;

typedef  i8  b8;
typedef i16 b16;
typedef i32 b32;
typedef i64 b64;

typedef struct str8 {
    u8 *str;
    usize len;
} str8;

#define str8_lit(s) (str8){ .len = sizeof(s) - 1, .str = (u8 *)s }

#define str8_expand(s) (s).str, (s).len

#include <stdlib.h>

typedef struct arena {
    void *mem;
    usize offset;
    usize cap;
} arena;

bool arena_init(arena *arena) {
    arena->offset = 0;
    if (arena->cap == 0) arena->cap = 8 * 1024 * 1024; 
    return (arena->mem = malloc(arena->cap));
}

void _arena_align(arena *arena, usize align) {
    usize modulo = arena->offset & (align - 1);
    if (modulo != 0) arena->offset += align - modulo;
}

#define ARENA_DEFAULT_ALIGNMENT (sizeof(void *))

void *arena_alloc(arena *arena, usize size) {
    _arena_align(arena, ARENA_DEFAULT_ALIGNMENT);
    if (arena->offset >= arena->cap) return NULL;
    void *ptr = (u8 *)arena->mem + arena->offset;
    arena->offset += size;
    return ptr;
}

void arena_deinit(arena *arena) {
    free(arena->mem);
    arena->offset = 0;
    arena->cap = 0;
}

#endif // BASE_H
