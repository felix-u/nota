#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <wchar.h>


#ifndef TOKEN_TYPE
#define TOKEN_TYPE

typedef struct token {
    size_t  row;
    size_t  col;
    uint8_t tok;
    size_t  lexeme_start;
    size_t  lexeme_end;
} token;

typedef struct token_SOA {
    size_t  len;
    size_t  cap;
    size_t  *row;
    size_t  *col;
    uint8_t *tok;
    size_t  *lexeme_start;
    size_t  *lexeme_end;
} token_SOA;

typedef enum token_Type {
    // Single-character syntax
    T_PAREN_LEFT               = '(',
    T_PAREN_RIGHT              = ')',
    T_SQUARE_BRACKET_LEFT      = '[',
    T_SQUARE_BRACKET_RIGHT     = ']',
    T_CURLY_BRACKET_LEFT       = '{',
    T_CURLY_BRACKET_RIGHT      = '}',
    T_COLON                    = ':',
    T_SEMICOLON                = ';',
    T_AT                       = '@',

    // Types
    T_STR = 256,
    T_NUM,

    // Directives
    T_MODS,
    T_PROVIDES,
    T_INHERITS,
    T_EOF,
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
        .len          = 0,
        .cap          = init_size,
        .row          = calloc(init_size, sizeof(size_t)),
        .col          = calloc(init_size, sizeof(size_t)),
        .tok          = calloc(init_size, sizeof(uint8_t)),
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
    tok_soa->len++;
    tok_soa->row          [tok_soa->len] = tok.row;
    tok_soa->col          [tok_soa->len] = tok.col;
    tok_soa->tok          [tok_soa->len] = tok.tok;
    tok_soa->lexeme_start [tok_soa->len] = tok.lexeme_start;
    tok_soa->lexeme_end   [tok_soa->len] = tok.lexeme_end;
}


typedef struct _token_ProcPosInfo {
    size_t  cursor;
    wchar_t *buf;
    size_t  bufsize;
    size_t  row;
    size_t  col;
} _token_ProcPosInfo;

void _token_process_pos_inc(_token_ProcPosInfo *pos) {
    if (pos->cursor < pos->bufsize) pos->cursor++;
    else return;
    if (pos->buf[cursor] == '\n') {
        if (pos->cursor < pos->bufsize) pos->cursor++;
        else return;
        pos->col = 0;
        pos->row++;
    }
}

void token_process(token_SOA *tok_soa, wchar_t *buf, const size_t bufsize) {

    wchar_t prev = 0;
    size_t  string_pairs_num = strlen(TOKEN_STRING_PAIRS);

    _token_ProcPosInfo pos = {
        .buf = buf,
        .bufsize = bufsize,
        .row = 1,
        .col = 1,
    };

    for (size_t cursor = 0; cursor < bufsize; cursor++) {

        // Skip strings
        for (size_t i = 0; i < string_pairs_num; i++) {
            if (buf[cursor] == TOKEN_STRING_PAIRS[i] && prev != '\\') {
                if (cursor < bufsize) cursor++;
                for (; (buf[cursor] != TOKEN_STRING_PAIRS[i] || prev == '\\') && cursor < bufsize; cursor++) {
                    prev = buf[cursor];
                }
                if (cursor < bufsize) cursor++;
                break;
            }
        }

        if (buf[cursor] != '@') continue;

        // {
        //     token tok_append = {
        //         .row = ,
        //         .col = ,
        //         .tok = '@',
        //         .lexeme = malloc(something),
        //     }
        //     tok_append.lexeme memcpy whatever
        //     token_SOA_append(tok_soa, tok_append);
        // }

        if (cursor < bufsize) cursor++;
        else break;
        for (; buf[cursor] != ';' && cursor < bufsize; cursor++) {
            // Get node name
            size_t name_start = cursor;
            while (!iswspace(buf[cursor]) && cursor < bufsize) cursor++;
            size_t name_end = cursor;
            for (size_t i = name_start; i < name_end; i++) {
                putwchar(buf[i]);
            }
            printf("\n");


            break;
        }

        prev = buf[cursor];
    }
}

#endif // TOKEN_IMPLEMENTATION
