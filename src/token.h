#ifndef TOKEN_H
#define TOKEN_H

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "better_int_types.h"

#endif // TOKEN_H


#ifndef TOKEN_TYPE
#define TOKEN_TYPE

typedef enum token_Type {
    // Single-character syntax
    T_PAREN_LEFT   = '(',
    T_PAREN_RIGHT  = ')',
    T_SQUARE_LEFT  = '[',
    T_SQUARE_RIGHT = ']',
    T_CURLY_LEFT   = '{',
    T_CURLY_RIGHT  = '}',
    T_SEMICOLON    = ';',
    T_AT           = '@',
    T_HASH         = '#',

    // Types
    T_STR = 128,
    T_NUM,
    T_DATE,

    // Directives
    T_MODS,
    T_PROVIDES,
    T_SHARES,

    T_EOF,
} token_Type;

typedef struct token {
    size_t     row;
    size_t     col;
    token_Type tok;
    size_t     lexeme_start;
    size_t     lexeme_end;
} token;

typedef struct token_SOA {
    size_t     len;
    size_t     cap;
    size_t     *row;
    size_t     *col;
    token_Type *tok;
    size_t     *lexeme_start;
    size_t     *lexeme_end;
} token_SOA;

#define TOKEN_STRING_PAIRS "\"'`"

#endif // TOKEN_TYPE


token_SOA token_SOA_init(size_t init_size);
void      token_SOA_free(token_SOA tok_soa);
void      token_SOA_append(token_SOA *tok_soa, token tok);
void      token_process(token_SOA *tok_soa, char *buf, size_t bufsize);


#ifdef TOKEN_IMPLEMENTATION

token_SOA token_SOA_init(size_t init_size) {
    return (token_SOA){
        .len          = 0,
        .cap          = init_size,
        .row          = calloc(init_size, sizeof(size_t)),
        .col          = calloc(init_size, sizeof(size_t)),
        .tok          = calloc(init_size, sizeof(token_Type)),
        .lexeme_start = calloc(init_size, sizeof(size_t)),
        .lexeme_end   = calloc(init_size, sizeof(size_t)),
    };
}


void token_SOA_free(token_SOA tok_soa) {
    free(tok_soa.row);
    free(tok_soa.col);
    free(tok_soa.tok);
    free(tok_soa.lexeme_start);
    free(tok_soa.lexeme_end);
}


void token_SOA_append(token_SOA *tok_soa, token tok) {
    if (tok_soa->len == tok_soa->cap) {
        tok_soa->cap *= 2;
        tok_soa->row           = realloc(tok_soa->row,          tok_soa->cap * sizeof(*tok_soa->row));
        tok_soa->col           = realloc(tok_soa->col,          tok_soa->cap * sizeof(*tok_soa->col));
        tok_soa->tok           = realloc(tok_soa->tok,          tok_soa->cap * sizeof(*tok_soa->tok));
        tok_soa->lexeme_start  = realloc(tok_soa->lexeme_start, tok_soa->cap * sizeof(*tok_soa->lexeme_start));
        tok_soa->lexeme_end    = realloc(tok_soa->lexeme_end,   tok_soa->cap * sizeof(*tok_soa->lexeme_end));
    }
    tok_soa->row          [tok_soa->len] = tok.row;
    tok_soa->col          [tok_soa->len] = tok.col;
    tok_soa->tok          [tok_soa->len] = tok.tok;
    tok_soa->lexeme_start [tok_soa->len] = tok.lexeme_start;
    tok_soa->lexeme_end   [tok_soa->len] = tok.lexeme_end;
    tok_soa->len++;
}

void token_process(token_SOA *tok_soa, char *buf, size_t bufsize) {
    (void) tok_soa;
    (void) buf;
    (void) bufsize;
    return;
}

#endif // TOKEN_IMPLEMENTATION
