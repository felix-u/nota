#ifndef PARSE_H
#define PARSE_H

#include "base.h"

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

typedef struct Token_SOA {
    u32 len;
    u8 *kind;
    u32 *beg_i;
    u32 *end_i;
} Token_SOA;

typedef struct Parse_Context {
    arena *arena;
    str8 path;
    str8 buf;
    u32 buf_i;
    Token_SOA tokens;
} Parse_Context;

Token token_soa_get(Parse_Context *ctx, u32 i);
void token_soa_set(Parse_Context *ctx, u32 i, Token token);
str8 token_lexeme(Parse_Context *ctx, u32 i);

bool parse_tokens_from_buf(Parse_Context *ctx);
char *parse_cstr_from_token_kind(Token_Kind kind);
void parse_print_tokens(Parse_Context *ctx);

#endif // PARSE_H


#ifdef PARSE_IMPLEMENTATION

Token token_soa_get(Parse_Context *ctx, u32 i) {
    return (Token){ 
        .kind = ctx->tokens.kind[i],
        .beg_i = ctx->tokens.beg_i[i],
        .end_i = ctx->tokens.end_i[i],
    };
}

void token_soa_set(Parse_Context *ctx, u32 i, Token token) {
    ctx->tokens.kind[i] = token.kind;
    ctx->tokens.beg_i[i] = token.beg_i;
    ctx->tokens.end_i[i] = token.end_i;
}

str8 token_lexeme(Parse_Context *ctx, u32 i) {
    const Token token = token_soa_get(ctx, i);
    return (str8){ 
        .ptr = ctx->buf.ptr + token.beg_i,
        .len = token.end_i - token.beg_i,
    };
}

#include <stdio.h>

bool parse_tokens_from_buf(Parse_Context *ctx) {
    ctx->tokens.kind = arena_alloc(ctx->arena, ctx->buf.len * sizeof(u8));
    ctx->tokens.beg_i = arena_alloc(ctx->arena, ctx->buf.len * sizeof(u32));
    ctx->tokens.end_i = arena_alloc(ctx->arena, ctx->buf.len * sizeof(u32));

    u8 c = '\0';
    u8 last = c;

    u32 tok_i = 0;
    u32 *i = &(ctx->buf_i);
    for (; *i < ctx->buf.len; *i += 1, last = c, c = ctx->buf.ptr[*i]) {
        switch (c) {
        case ' ': case '\n': case '\t': case '\r': 
            continue;
            break;
        case '{': case '}': case '(': case ')': case '=': case ';': case ':':
        case '!': case '>': case '<': case '#': case '@':
            token_soa_set(ctx, tok_i, (Token){ 
                .kind = c, .beg_i = *i, .end_i = *i + 1, 
            });
            tok_i += 1;
            break;
        case '/':
            // TODO: comments
            break;
        case '"':
            *i += 1;
            if (*i >= ctx->buf.len) break;

            u32 str_beg = *i;

            while (*i < ctx->buf.len && (c != '"' || last == '\\')) {
                last = c;
                *i += 1;
                c = ctx->buf.ptr[*i];
            }

            u32 str_end = *i;

            token_soa_set(ctx, tok_i, (Token){ 
                .kind = TOKEN_STR, .beg_i = str_beg, .end_i = str_end,
            });
            tok_i += 1;

            break;
        default:
            // TODO: num or symbol
            break;
        }
    }

    ctx->tokens.kind[tok_i] = TOKEN_EOF;
    ctx->tokens.len = tok_i + 1;
    
    return true;
}

char *parse_cstr_from_token_kind(Token_Kind kind) {
    if (kind < 128) return (char[]){ kind, '\0' };

    switch (kind) {
    case TOKEN_STR: return "TOKEN_STR"; break;
    case TOKEN_NUM: return "TOKEN_NUM"; break;
    case TOKEN_DATE: return "TOKEN_DATE"; break;
    case TOKEN_SYMBOL: return "TOKEN_SYMBOL"; break;
    case TOKEN_EOF: return "TOKEN_EOF"; break;
    case TOKEN_FALSE: return "TOKEN_FALSE"; break;
    case TOKEN_TRUE: return "TOKEN_TRUE"; break;
    case TOKEN_FOR: return "TOKEN_FOR"; break;
    case TOKEN_IF: return "TOKEN_IF"; break;
    default: return NULL; break;
    }

    return NULL;
}

void parse_print_tokens(Parse_Context *ctx) {
    const Token_SOA tokens = ctx->tokens;
    for (u32 i = 0; i < tokens.len; i++) {
        printf("%d\t%s\t", i, parse_cstr_from_token_kind(tokens.kind[i]));
        str8_print(stdout, token_lexeme(ctx, i));
        putchar('\n');
    }
}

#endif // PARSE_IMPLEMENTATION
