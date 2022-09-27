#include <wctype.h>


typedef struct Node {
    struct Node *parent;
    wint_t *name;
    wint_t *desc;
    wint_t *date;
    wint_t *text;
    struct Node *children;
} Node;

typedef struct Delimiter {
    wint_t beg;
    wint_t end;
} Delimiter;
