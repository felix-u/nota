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

#define TOKEN_IGNORE_IN_PAIRS "\"'`"

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
    size_t  ignore_in_pairs_num = strlen(TOKEN_IGNORE_IN_PAIRS);
    bool    inside_pairs[ignore_in_pairs_num];
    memset(inside_pairs, false, sizeof inside_pairs);

    bool inside_string = false;
    for (size_t i = 0; i < bufsize; i++) {

        // We need this to ignore @ if it's in a string.
        for (size_t j = 0; j < ignore_in_pairs_num; j++) {
            if (buf[i] == TOKEN_IGNORE_IN_PAIRS[j] && prev != '\\') {
                inside_pairs[j] = !inside_pairs[j];
                break;
            }
        }
        bool in_any_string_pair = false;
        for (size_t j = 0; j < ignore_in_pairs_num; j++) {
            if (inside_pairs[j]) {
                in_any_string_pair = true;
                inside_string = true;
                break;
            }
        }
        if (!in_any_string_pair) inside_string = false;

        if (inside_string) ansi_set("%s", ANSI_FG_RED);
        printf("%lc", buf[i]);
        if (!inside_string) ansi_reset();
        prev = buf[i];
    }
}

#endif // TOKEN_IMPLEMENTATION
