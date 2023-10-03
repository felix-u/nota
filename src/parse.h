#ifndef PARSE_H
#define PARSE_H

#include "base.h"

typedef struct Parse_Context {
    str8 path;
    str8 buf;
    u32 buf_i;
} Parse_Context;

#endif // PARSE_H
