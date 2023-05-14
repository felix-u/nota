#ifndef ALLOCATORS_H
#define ALLOCATORS_H

#include <stdlib.h>
#include <stdbool.h>

// // WIP
// typedef struct SLinkedList {
//     void *first;
// } SLinkedList;

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


// // WIP
// typedef struct ArenaAllocator {
//     Allocator child_allocator;
//     struct {
//         SLinkedList buffer_list;
//         size_t end_index;
//     } state;
//     (Allocator)      (*allocator) ();
//     (void)           (*deinit) ();
//     (ArenaAllocator) (*init) (Allocator child_allocator);
//     (size_t)         (*capacity);
//     (bool)           (*clear) ();
//     (bool)           (*free) ();
// } ArenaAllocator;



#endif // ALLOCATORS_H
