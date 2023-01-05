#include <stdlib.h>


#ifndef ARENA_TYPE
#define ARENA_TYPE

typedef struct arena {
    size_t len;
    size_t cap;
    void **ptrs;
} arena;

#endif // ARENA_TYPE


arena *arena_new(size_t init_size);
void arena_init(arena *a, size_t init_size);
void arena_append(arena *a, void *ptr);
void arena_free(arena *a);
void arena_freeCustom(arena *a, void (*free_custom)(void *));
void arena_empty(arena *a);
void arena_emptyFree(arena *a);
void arena_emptyFreeCustom(arena *a, void (*free_custom)(void *));


#ifdef ARENA_IMPLEMENTATION

arena *arena_new(size_t init_size) {
    arena *a = &(arena){
        0,
        init_size,
        malloc(init_size * sizeof(void *))
    };
    return a;
}


void arena_init(arena *a, size_t init_size) {
    a->len = 0;
    a->cap = init_size;
    a->ptrs = malloc(init_size * sizeof(void *));
}


void arena_append(arena *a, void *ptr) {
    if (a->len == a->cap) {
        a->cap *= 2;
        a->ptrs = realloc(a->ptrs, a->cap * sizeof(void *));
    }
    a->ptrs[a->len++] = ptr;
}


void arena_free(arena *a) {
    for (size_t i = 0; i < a->len; i++) free(a->ptrs[i]);
    free(a->ptrs);
}


void arena_freeCustom(arena *a, void (*free_custom)(void *)) {
    for (size_t i = 0; i < a->len; i++) free_custom(a->ptrs[i]);
    free(a->ptrs);
}


void arena_empty(arena *a) {
    a->len = 0;
}


void arena_emptyFree(arena *a) {
    for (size_t i = 0; i < a->len; i++) free(a->ptrs[i]);
    a->len = 0;
}


void arena_emptyFreeCustom(arena *a, void (*free_custom)(void *)) {
    for (size_t i = 0; i < a->len; i++) free_custom(a->ptrs[i]);
    a->len = 0;
}

#endif // ARENA_IMPLEMENTATION
