// 2023-10-02
#ifndef BASE_H
#define BASE_H

#include <stdbool.h>

#include <stdint.h>
#include <stdlib.h>

typedef   uint8_t    u8;
typedef  uint16_t   u16;
typedef  uint32_t   u32;
typedef  uint64_t   u64;
typedef    int8_t    i8;
typedef   int16_t   i16;
typedef   int32_t   i32;
typedef   int64_t   i64;
typedef    size_t usize;
typedef  intptr_t isize;
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

#endif // BASE_H
