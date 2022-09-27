#include <wctype.h>


typedef struct Node {
    struct Node *parent;
    wint_t *name;
    wint_t *desc;
    wint_t *date;
    wint_t *text;
    struct Node *children;
} Node;
