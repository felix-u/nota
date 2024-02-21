#include <assert.h>

typedef enum {
    // ASCII characters not enumerated here
    parse_token_kind_ascii_end = 128,

    parse_token_kind_symbol,
    parse_token_kind_string,

    parse_token_kind_count,
} Parse_Token_Kind;

typedef struct {
    Parse_Token_Kind kind;
    u32 beg_i;
    u32 end_i;
} Parse_Token;

typedef Slice(Parse_Token) Parse_Token_Slice;

typedef enum {
    parse_sexpr_kind_atom,
    parse_sexpr_kind_pair,
} Parse_Sexpr_Kind;

typedef struct {
    Parse_Sexpr_Kind kind; 
    u32 lhs;
    u32 rhs;
} Parse_Sexpr;

typedef Slice(Parse_Sexpr) Parse_Sexpr_Slice;

typedef struct {
    Arena arena;
    int argc;
    char **argv;

    Str8 path;
    Str8 bytes;

    Parse_Token_Slice toks;

    u32 tok_i;
    Parse_Sexpr ast_root;
    Parse_Sexpr_Slice sexprs;
} Parse_Context;

const bool parse_char_is_whitespace_table[256] = {
    ['\r'] = 1, ['\n'] = 1, [' '] = 1, ['\t'] = 1,
};

const bool parse_char_is_syntax_table[256] = { ['('] = 1, [')'] = 1, };

static bool parse_char_is_symbol(u8 c) {
    return 
        !parse_char_is_whitespace_table[c] &&
        !parse_char_is_syntax_table[c];
}

static Str8 parse_tok_lexeme(Parse_Context *ctx, Parse_Token tok) {
    return str8_range(ctx->bytes, tok.beg_i, tok.end_i);
}

static Str8 parse_string_from_token_kind(Parse_Token_Kind kind) {
    if (kind < parse_token_kind_ascii_end) return str8("<character>");
    switch (kind) {
        case parse_token_kind_symbol: return str8("<symbol>"); break;
        case parse_token_kind_string: return str8("<string>"); break;
        default: assert(false && "unreachable");
    }
}

static void parse_print_tokens(Parse_Context *ctx) {
    Parse_Token_Slice toks = ctx->toks;
    for (u32 i = 0; i < toks.len; i += 1) {
        Parse_Token tok = toks.ptr[i];
        Str8 lexeme = parse_tok_lexeme(ctx, tok);
        Str8 tok_kind_string = parse_string_from_token_kind(tok.kind);
        printf("%d\t%.*s\t%.*s\n", i, str8_fmt(lexeme), str8_fmt(tok_kind_string));
    }
}

static error parse_lex(Parse_Context *ctx) {
    Str8 buf = ctx->bytes;
    Parse_Token_Slice *toks = &ctx->toks;
    try (arena_alloc(&ctx->arena, buf.len * sizeof(Parse_Token), &toks->ptr));

    for (u32 i = 0; i < buf.len; i += 1) {
        if (parse_char_is_whitespace_table[buf.ptr[i]]) continue;

        if (parse_char_is_syntax_table[buf.ptr[i]]) {
            slice_push(*toks, ((Parse_Token){
                .kind = buf.ptr[i],
                .beg_i = i,
                .end_i = i + 1,
            }));
            continue;
        }

        if (buf.ptr[i] == '"') {
            i += 1;
            u32 string_beg_i = i;
            while (i < buf.len && buf.ptr[i] != '"') i += 1;
            if (i >= buf.len) return err("string never terminates");
            u32 string_end_i = i;

            slice_push(*toks, ((Parse_Token){
                .kind = parse_token_kind_string,
                .beg_i = string_beg_i,
                .end_i = string_end_i,
            }));
            continue;
        }

        u32 symbol_beg_i = i;
        while (i < buf.len && parse_char_is_symbol(buf.ptr[i])) i += 1;
        u32 symbol_end_i = i;
        slice_push(*toks, ((Parse_Token){ 
            .kind = parse_token_kind_symbol, 
            .beg_i = symbol_beg_i,
            .end_i = symbol_end_i,
        }));
    }

    return 0;
}

static error parse_ast_from_toks(Parse_Context *ctx) {
    Parse_Token_Slice toks = ctx->toks;
    Parse_Sexpr_Slice *sexprs = &ctx->sexprs;
    u32 *i = &ctx->tok_i;
    if (*i == 0) try (
        arena_alloc(&ctx->arena, toks.len * sizeof(Parse_Sexpr), &sexprs->ptr)
    );

    for (
        Parse_Token tok = toks.ptr[*i]; 
        *i < toks.len; 
        *i += 1, tok = toks.ptr[*i]
    ) {
        if (tok.kind == ')') return 0;
        if (tok.kind == '(') {
            *i += 1;
            try (parse_ast_from_toks(ctx)); 
            continue;
        }
        switch (tok.kind) {
            case parse_token_kind_symbol: {
                return err("unimplemented");
            }; break;
            case parse_token_kind_string: {
                return err("unimplemented");
            }; break;
            default: {
                return errf("invalid token at index %d", *i);
            }break;
        }
    }

    return 0;
}

