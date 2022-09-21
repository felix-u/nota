#include <wctype.h>


typedef struct Node {
    wint_t name[256];
    wint_t desc[256];
    wint_t date[256];
    wint_t *text;
} Node;
