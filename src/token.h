#ifndef TOKEN_H
#define TOKEN_H

#include "base.h"

#include "parse.h"

typedef enum Token_Kind {
    TOKEN_NULL = 0,
    
    // ASCII syntax characters are not explicitly included. Token_Kind is
    // either a syntax character or an enum value after TOKEN_CHARS.

    TOKEN_CHARS = 128,

    TOKEN_STR,
    TOKEN_NUM,
    TOKEN_DATE,
    TOKEN_SYMBOL,

    TOKEN_EOF,

    TOKEN_KEYWORD_BEG,

    TOKEN_FALSE,
    TOKEN_TRUE,

    TOKEN_CONTROL_BEG,
    TOKEN_FOR,
    TOKEN_IF,
    TOKEN_CONTROL_END,

    TOKEN_KEYWORD_END,
    
    TOKEN_COUNT,
} Token_Kind;

typedef struct Token {
    u8 kind;
    u32 beg_i;
    u32 end_i;
} Token;

bool token_from_buf(Parse_Context *pctx) {
    u8 c = 0;

    for (u32 i = 0; i < pctx->buf.len; i += 1, c = pctx->buf.str[i]) {
        switch (c) {
        case ' ': case '\n': case '\t': case '\r': 
            break;
        case '{': case '}': case '(': case ')': case '=': case ';': case ':':
        case '!': case '>': case '<': case '#': case '@':
            // TODO: append to token list
            break;
        case '/':
            // TODO: comments
            break;
        case '"':
            // TODO: strings
            break;
        default:
            // TODO: num or symbol
            break;
        }
    }

    // TODO: append EOF

    return true;
}

#endif // TOKEN_H
