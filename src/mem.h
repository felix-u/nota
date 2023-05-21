#ifndef MEM_H
#define MEM_H

#include <stdbool.h>
#include <stdlib.h>

// Generic allocator interface

typedef struct Allocator {
    void *(*alloc)   (size_t n, size_t type_size);
    void  (*free)    (void *mem);
    void *(*realloc) (void *old_mem, size_t new_n);
} Allocator;

// Allocators

// Wraps calloc, realloc, and free
const Allocator c_allocator = {
    .alloc   = calloc,
    .free    = free,
    .realloc = realloc,
};

#endif // MEM_H


// Arrays

#ifdef ARR_TYPE

#define ARR_CONCAT_(x, y) x ## y
#define ARR_CONCAT(x, y) ARR_CONCAT_(x, y)

#define ARR_TYPE_NAME ARR_CONCAT(ARR_TYPE, arr)
#define ARR_INIT_NAME ARR_CONCAT(ARR_TYPE_NAME, _init)
#define ARR_PUSH_NAME ARR_CONCAT(ARR_TYPE_NAME, _push)
#define ARR_LEN(arr) (((size_t *)(arr))[-1])
#define ARR_CAP(arr) (((size_t *)(arr))[-2])

#define ARR_PTR_OFFSET (sizeof(size_t) * 2)

ARR_TYPE *ARR_INIT_NAME(size_t init_size, Allocator allocator) {
    size_t *data = (size_t *)allocator.alloc(1, ARR_PTR_OFFSET + init_size * sizeof(ARR_TYPE));
    data[0] = init_size; // capacity
    data[1] = 0; // length
    return (ARR_TYPE *)(data + 2);
}

void arr_free(void *arr, Allocator allocator) {
    allocator.free((size_t *)arr - 2);
}

void ARR_PUSH_NAME(ARR_TYPE **arr, ARR_TYPE e, Allocator allocator) {
    size_t *metadata = (size_t *)(*arr) - 2;
    size_t cap = metadata[0];
    size_t len = metadata[1];
    if (len == cap) {
        cap = (cap == 0) ? 1 : cap * 2;
        size_t *new_data = (size_t *)allocator.realloc(metadata, ARR_PTR_OFFSET + cap * sizeof(ARR_TYPE));
        new_data[0] = cap;
        new_data[1] = len;
        *arr = (ARR_TYPE *)(new_data + 2);
    }
    (*arr)[ARR_LEN(*arr)++] = e;
}

#endif // ARR_TYPE