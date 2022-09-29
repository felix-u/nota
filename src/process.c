#include <stdbool.h>
#include <wctype.h>


typedef struct Delimiter {
    wint_t beg;
    wint_t end;
} Delimiter;


bool isWhiteSpace(char c) {
    if (c == ' ' || c == '\n' || c == '\t') return true;
    return false;
}
