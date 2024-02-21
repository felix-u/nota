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
    parse_sexpr_kind_nil,
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

static void parse_print_token(Parse_Context *ctx, Parse_Token tok) {
    Str8 lexeme = parse_tok_lexeme(ctx, tok);
    Str8 tok_kind_string = parse_string_from_token_kind(tok.kind);
    printf("'%.*s' %.*s", str8_fmt(lexeme), str8_fmt(tok_kind_string));
}

static void parse_print_tokens(Parse_Context *ctx) {
    Parse_Token_Slice toks = ctx->toks;
    for (u32 i = 0; i < toks.len; i += 1) {
        printf("%3d ", i);
        parse_print_token(ctx, toks.ptr[i]);
        printf("\n");
    }
}

static Str8 parse_string_from_sexpr_kind(Parse_Sexpr_Kind kind) {
    switch (kind) {
        case parse_sexpr_kind_nil : return str8("<NIL>");  break;
        case parse_sexpr_kind_atom: return str8("<atom>"); break;
        case parse_sexpr_kind_pair: return str8("<pair>"); break;
    }
}

static void parse_print_sexpr_info(Parse_Sexpr sexpr) {
    Str8 sexpr_kind_string = parse_string_from_sexpr_kind(sexpr.kind);
    printf("%.*s l%d r%d", str8_fmt(sexpr_kind_string), sexpr.lhs, sexpr.rhs);
}

static void parse_print_sexpr(
    Parse_Context *ctx, 
    Parse_Sexpr sexpr, 
    usize indent_level
) {
    Parse_Sexpr_Slice sexprs = ctx->sexprs;
    for (usize i = 0; i < indent_level; i += 1) printf("    ");

    switch (sexpr.kind) {
        case parse_sexpr_kind_nil: printf("<nil>\n"); break;
        case parse_sexpr_kind_atom: {
            parse_print_sexpr_info(sexpr);
            putchar(' ');
            parse_print_token(ctx, ctx->toks.ptr[sexpr.lhs]);
            putchar('\n');
        } break;
        case parse_sexpr_kind_pair: {
            parse_print_sexpr_info(sexpr);
            putchar('\n');
            for (
                u32 sexpr_i = sexpr.lhs; 
                sexpr_i != 0; 
                sexpr_i = sexprs.ptr[sexpr_i].rhs
            ) {
                parse_print_sexpr(ctx, sexprs.ptr[sexpr_i], indent_level + 1);
            }
        } break;
    }
}

static void parse_print_ast(Parse_Context *ctx) {
    for (u32 i = 0; i < ctx->sexprs.len; i += 1) {
        printf("%3d ", i);
        parse_print_sexpr_info(ctx->sexprs.ptr[i]);
        putchar('\n');
    }
    printf("\nTREE:\n");
    u32 sexpr_i = 0;
    do {
        parse_print_sexpr(ctx, ctx->sexprs.ptr[sexpr_i], 0);
        sexpr_i = ctx->sexprs.ptr[sexpr_i].rhs;
    } while (sexpr_i != 0);
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
        i -= 1;
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
        if (tok.kind == ')') {
            slice_push(*sexprs, ((Parse_Sexpr){
                .kind = parse_sexpr_kind_nil,
                .lhs = *i,
            }));
            return 0;
        }
        if (tok.kind == '(') {
            *i += 1;
            u32 lhs = (u32)sexprs->len + 1;
            u32 sexpr_to_fix_rhs_i = (u32)sexprs->len;
            slice_push(*sexprs, ((Parse_Sexpr){
                .kind = parse_sexpr_kind_pair,
                .lhs = lhs,
            }));
            try (parse_ast_from_toks(ctx)); 
            sexprs->ptr[sexpr_to_fix_rhs_i].rhs = (u32)sexprs->len;
            continue;
        }
        switch (tok.kind) {
            case parse_token_kind_symbol: 
            case parse_token_kind_string: 
            {
                u32 rhs = (u32)sexprs->len + 1;
                slice_push(*sexprs, ((Parse_Sexpr){
                    .kind = parse_sexpr_kind_atom,
                    .lhs = *i,
                    .rhs = rhs,
                }));
            }; break;
            default: {
                return errf("invalid token at index %d", *i);
            }break;
        }
    }

    slice_push(*sexprs, ((Parse_Sexpr){ .kind = parse_sexpr_kind_nil }));
    return 0;
}

