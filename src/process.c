#include <stdbool.h>


bool isWhiteSpace(char c) {
    if (c == ' ' || c == '\n' || c == '\t') return true;
    return false;
}
