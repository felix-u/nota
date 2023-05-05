#ifndef ARR_H
#define ARR_H

#include <stdlib.h>

#endif // ARR_H


#ifdef ARR_TYPE

#define ARR_CONCAT_(x, y) x ## y
#define ARR_CONCAT(x, y) ARR_CONCAT_(x, y)

#define ARR_TYPE_NAME ARR_CONCAT(ARR_TYPE, arr)
#define ARR_INIT_NAME ARR_CONCAT(ARR_TYPE_NAME, _init)
#define ARR_FREE_NAME ARR_CONCAT(ARR_TYPE_NAME, _free)
#define ARR_PUSH_NAME ARR_CONCAT(ARR_TYPE_NAME, _push)
#define arr_len(arr) (((size_t *)(arr))[-1])
#define arr_cap(arr) (((size_t *)(arr))[-2])

#define ARR_PTR_OFFSET (sizeof(size_t) * 2)

ARR_TYPE *ARR_INIT_NAME(size_t init_size) {
    size_t *data = (size_t *)calloc(1, ARR_PTR_OFFSET + init_size * sizeof(ARR_TYPE));
    data[0] = init_size; // capacity
    data[1] = 0; // length
    return (ARR_TYPE *)(data + 2);
}

void ARR_FREE_NAME(ARR_TYPE *arr) {
    free((size_t *)arr - 2);
}

void ARR_PUSH_NAME(ARR_TYPE **arr, ARR_TYPE e) {
    size_t *metadata = (size_t *)(*arr) - 2;
    size_t cap = metadata[0];
    size_t len = metadata[1];
    if (len == cap) {
        cap = (cap == 0) ? 1 : cap * 2;
        size_t *new_data = (size_t *)realloc(metadata, ARR_PTR_OFFSET + cap * sizeof(ARR_TYPE));
        new_data[0] = cap;
        new_data[1] = len;
        *arr = (ARR_TYPE *)(new_data + 2);
    }
    (*arr)[arr_len(*arr)++] = e;
}

#endif // ARR_TYPE
