#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <wchar.h>


#ifndef TOKEN_TYPE
#define TOKEN_TYPE

typedef struct token {
    size_t row;
    size_t col;
    uint8_t tok;
    wchar_t *lexeme;
} token;

typedef struct token_SOA {
    size_t len;
    size_t cap;
    size_t  *row;
    size_t  *col;
    uint8_t *tok;
    wchar_t **lexeme;
} token_SOA;

typedef enum token_Type {
    // Single-character syntax
    T_PAREN_LEFT, T_PAREN_RIGHT, T_SQUARE_BRACKET_LEFT, T_SQUARE_BRACKET_RIGHT,
    T_CURLY_BRACKET_LEFT, T_CURLY_BRACKET_RIGHT, T_COLON, T_SEMICOLON, T_AT,
    // Types
    T_STR, T_NUM,
    // Directives
    T_MODS, T_PROVIDES, T_INHERITS,
    T_EOF,
    T_COUNT
} token_Type;

#define TOKEN_STRING_PAIRS "\"'`"

#endif // TOKEN_TYPE


token_SOA token_SOA_init(size_t init_size);
void      token_SOA_free(token_SOA tok_soa);
void      token_SOA_append(token_SOA *tok_soa, token tok);
void      token_process(token_SOA *tok_soa, wchar_t *buf, size_t bufsize);


#ifdef TOKEN_IMPLEMENTATION

token_SOA token_SOA_init(size_t init_size) {
    return (token_SOA){
        .len    = 0,
        .cap    = init_size,
        .row    = malloc(init_size * sizeof(size_t)),
        .col    = malloc(init_size * sizeof(size_t)),
        .tok    = malloc(init_size * sizeof(uint8_t)),
        .lexeme = malloc(init_size * sizeof(wchar_t)),
    };
}


void token_SOA_free(token_SOA tok_soa) {
    if (tok_soa.row != NULL) free(tok_soa.row);
    if (tok_soa.col != NULL) free(tok_soa.col);
    if (tok_soa.tok != NULL) free(tok_soa.tok);
}


void token_SOA_append(token_SOA *tok_soa, token tok) {
    if (tok_soa->len == tok_soa->cap) {
        tok_soa->cap *= 2;
        tok_soa->row    = realloc(tok_soa->row,    tok_soa->cap * sizeof(*tok_soa->row));
        tok_soa->col    = realloc(tok_soa->col,    tok_soa->cap * sizeof(*tok_soa->col));
        tok_soa->tok    = realloc(tok_soa->tok,    tok_soa->cap * sizeof(*tok_soa->tok));
        tok_soa->lexeme = realloc(tok_soa->lexeme, tok_soa->cap * sizeof(*tok_soa->lexeme));
    }
    tok_soa->len++;
    tok_soa->row   [tok_soa->len] = tok.row;
    tok_soa->col   [tok_soa->len] = tok.col;
    tok_soa->tok   [tok_soa->len] = tok.tok;
    tok_soa->lexeme[tok_soa->len] = tok.lexeme;
}


void token_process(token_SOA *tok_soa, wchar_t *buf, const size_t bufsize) {

    wchar_t prev = 0;
    size_t  string_pairs_num = strlen(TOKEN_STRING_PAIRS);

    for (size_t cursor = 0; cursor < bufsize; cursor++) {

        // Skip strings
        for (size_t i = 0; i < string_pairs_num; i++) {
            if (buf[cursor] == TOKEN_STRING_PAIRS[i] && prev != '\\') {
                cursor++;
                for (; buf[cursor] != TOKEN_STRING_PAIRS[i] || prev == '\\'; cursor++) {
                    ansi_set("%s", ANSI_FG_RED);
                    printf("%lc", buf[cursor]);
                    prev = buf[cursor];
                }
                cursor++;
                break;
            }
        }

        ansi_reset();
        printf("%lc", buf[cursor]);
        prev = buf[cursor];
    }
}

#endif // TOKEN_IMPLEMENTATION
