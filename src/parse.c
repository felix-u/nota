#include <assert.h>

typedef enum {
    // ASCII characters not enumerated here
    parse_token_kind_ascii_end = 128,

    parse_token_kind_ident,
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

typedef enum {
    parse_sexpr_as_literal,
    parse_sexpr_as_ident,
    parse_sexpr_as_symbol,
} Parse_Sexpr_As;

typedef struct {
    u16 kind;
    u16 as;
} Parse_Sexpr_Tag;

typedef struct {
    Parse_Sexpr_Tag tag;
    u32 lhs;
    u32 rhs;
} Parse_Sexpr;
typedef Slice(Parse_Sexpr) Parse_Sexpr_Slice;

typedef error (*parse_eval_fn)(
    void *ctx, 
    Parse_Sexpr sexpr, 
    Parse_Sexpr *out_sexpr
);
typedef struct {
    Str8 name;
    parse_eval_fn eval_fn;
} Parse_Function;
typedef Slice(Parse_Function) Parse_Function_Slice;

typedef enum {
    parse_literal_type_string,
} Parse_Literal_Type;
typedef struct {
    Parse_Literal_Type type;
    union {
        Str8 str;
    } data;
} Parse_Literal;
typedef Slice(Parse_Literal) Parse_Literal_Slice;

typedef struct {
    u32 name_tok_i;
    u32 value_sexpr_i;
} Parse_Ident;
typedef Slice(Parse_Ident) Parse_Ident_Slice;

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
    Parse_Function_Slice functions;
    Parse_Literal_Slice literals;
    Parse_Ident_Slice idents;
} Parse_Context;

const bool parse_char_is_whitespace_table[256] = {
    ['\r'] = 1, ['\n'] = 1, [' '] = 1, ['\t'] = 1,
};

const bool parse_char_is_syntax_table[256] = { 
    ['('] = 1, [')'] = 1, ['\''] = 1
};

static bool parse_char_is_ident(u8 c) {
    return 
        !parse_char_is_whitespace_table[c] &&
        !parse_char_is_syntax_table[c];
}

static Str8 parse_tok_lexeme(Parse_Context *ctx, Parse_Token tok) {
    return str8_range(ctx->bytes, tok.beg_i, tok.end_i);
}

static Parse_Ident *parse_lookup_ident(Parse_Context *ctx, Str8 name) {
    for (u32 i = 0; i < ctx->idents.len; i += 1) {
        Parse_Ident ident = ctx->idents.ptr[i];
        Str8 ident_name = 
            parse_tok_lexeme(ctx, ctx->toks.ptr[ident.name_tok_i]);
        if (!str8_eql(ident_name, name)) continue;
        return &ctx->idents.ptr[i];
    }
    return NULL;
}

static Str8 parse_string_from_token_kind(Parse_Token_Kind kind) {
    if (kind < parse_token_kind_ascii_end) return str8("<character>");
    switch (kind) {
        case parse_token_kind_ident: return str8("token<ident>"); break;
        case parse_token_kind_string: return str8("token<string>"); break;
        default: assert(false && "unreachable");
    }
    return str8("unreachable");
}

static void parse_print_token(Parse_Context *ctx, Parse_Token tok) {
    Str8 lexeme = parse_tok_lexeme(ctx, tok);
    Str8 tok_kind_string = parse_string_from_token_kind(tok.kind);
    printf("%.*s '%.*s'", str8_fmt(tok_kind_string), str8_fmt(lexeme));
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
        case parse_sexpr_kind_nil : return str8("Sexpr<NIL>");  break;
        case parse_sexpr_kind_atom: return str8("Sexpr<atom>"); break;
        case parse_sexpr_kind_pair: return str8("Sexpr<list>"); break;
    }
}

static Str8 parse_string_from_sexpr_as(Parse_Sexpr_As as) {
    switch (as) {
        case parse_sexpr_as_ident:  return str8("(ident)");  break;
        case parse_sexpr_as_literal: return str8("(literal)"); break;
        case parse_sexpr_as_symbol:  return str8("(symbol)");  break;
    }
}

static void parse_print_literal(Parse_Literal literal) {
    switch (literal.type) {
        case parse_literal_type_string: {
            printf("literal<string> '%.*s'", str8_fmt(literal.data.str));
        }; break;
    }
}

static void parse_print_sexpr_info(Parse_Context *ctx, Parse_Sexpr sexpr) {
    Str8 sexpr_kind_string = parse_string_from_sexpr_kind(sexpr.tag.kind);
    Str8 sexpr_as_string = parse_string_from_sexpr_as(sexpr.tag.as);
    printf(
        "%.*s%.*s l%d r%d ", 
        str8_fmt(sexpr_kind_string), 
        str8_fmt(sexpr_as_string), 
        sexpr.lhs, sexpr.rhs
    );
    if (sexpr.tag.kind == parse_sexpr_kind_atom) {
        switch ((Parse_Sexpr_As)sexpr.tag.as) {
            case parse_sexpr_as_ident:
            case parse_sexpr_as_symbol: {
                parse_print_token(ctx, ctx->toks.ptr[sexpr.lhs]);
            } break;
            case parse_sexpr_as_literal: {
                parse_print_literal(ctx->literals.ptr[sexpr.lhs]);
            } break;
        }
    }
}

static void parse_print_sexpr(
    Parse_Context *ctx, 
    Parse_Sexpr sexpr, 
    usize indent_level
) {
    Parse_Sexpr_Slice sexprs = ctx->sexprs;
    for (usize i = 0; i < indent_level; i += 1) printf("    ");

    switch (sexpr.tag.kind) {
        case parse_sexpr_kind_nil: printf("<nil>\n"); break;
        case parse_sexpr_kind_atom: {
            parse_print_sexpr_info(ctx, sexpr);
            putchar('\n');
        } break;
        case parse_sexpr_kind_pair: {
            parse_print_sexpr_info(ctx, sexpr);
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
        parse_print_sexpr_info(ctx, ctx->sexprs.ptr[i]);
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

        u32 ident_beg_i = i;
        while (i < buf.len && parse_char_is_ident(buf.ptr[i])) i += 1;
        u32 ident_end_i = i;
        slice_push(*toks, ((Parse_Token){ 
            .kind = parse_token_kind_ident, 
            .beg_i = ident_beg_i,
            .end_i = ident_end_i,
        }));
        i -= 1;
    }

    return 0;
}

static error parse_ast_from_toks(Parse_Context *ctx) {
    Parse_Token_Slice toks = ctx->toks;
    Parse_Sexpr_Slice *sexprs = &ctx->sexprs;
    u32 *i = &ctx->tok_i;
    if (*i == 0) {
        try (arena_alloc(
            &ctx->arena, 
            toks.len * sizeof(Parse_Sexpr), 
            &sexprs->ptr
        )); 
        try (arena_alloc(
            &ctx->arena,
            toks.len * sizeof(Parse_Literal),
            &ctx->literals.ptr
        ));
    }

    for (
        Parse_Token tok = toks.ptr[*i]; 
        *i < toks.len; 
        *i += 1, tok = toks.ptr[*i]
    ) {
        Parse_Sexpr_As as = parse_sexpr_as_ident;
        if (tok.kind == parse_token_kind_string) as = parse_sexpr_as_literal;
        else if (tok.kind == '\'') {
            as = parse_sexpr_as_symbol;
            *i += 1;
            if (*i == toks.len) break;
            tok = toks.ptr[*i];
        }

        if (tok.kind == ')') {
            slice_push(*sexprs, ((Parse_Sexpr){
                .tag = (Parse_Sexpr_Tag){
                    .kind = parse_sexpr_kind_nil,
                    .as = parse_sexpr_as_ident,
                },
                .lhs = *i,
            }));
            return 0;
        }
        if (tok.kind == '(') {
            *i += 1;
            u32 lhs = (u32)sexprs->len + 1;
            u32 sexpr_to_fix_rhs_i = (u32)sexprs->len;
            slice_push(*sexprs, ((Parse_Sexpr){
                .tag = (Parse_Sexpr_Tag){
                    .kind = parse_sexpr_kind_pair,
                    .as = (u16)as,
                },
                .lhs = lhs,
            }));
            try (parse_ast_from_toks(ctx)); 
            sexprs->ptr[sexpr_to_fix_rhs_i].rhs = (u32)sexprs->len;
            continue;
        }
        switch (tok.kind) {
            case parse_token_kind_string: {
                slice_push(ctx->literals, ((Parse_Literal){
                    .type = parse_literal_type_string,
                    .data.str = parse_tok_lexeme(ctx, tok),
                }));
                u32 rhs = (u32)sexprs->len + 1;
                slice_push(*sexprs, ((Parse_Sexpr){
                    .tag = (Parse_Sexpr_Tag){
                        .kind = parse_sexpr_kind_atom,
                        .as = (u16)as,
                    },
                    .lhs = (u32)ctx->literals.len - 1,
                    .rhs = rhs,
                }));
            } break;
            case parse_token_kind_ident: {
                u32 rhs = (u32)sexprs->len + 1;
                slice_push(*sexprs, ((Parse_Sexpr){
                    .tag = (Parse_Sexpr_Tag){
                        .kind = parse_sexpr_kind_atom,
                        .as = (u16)as,
                    },
                    .lhs = *i,
                    .rhs = rhs,
                }));
            }; break;
            default: {
                return errf("invalid token at index %d", *i);
            } break;
        }
    }

    slice_push(*sexprs, ((Parse_Sexpr){ .tag = (Parse_Sexpr_Tag){
        .kind = parse_sexpr_kind_nil,
        .as = parse_sexpr_as_ident,
    } }));
    return 0;
}

static error parse_ensure_arity(
    Parse_Context *ctx, 
    Parse_Sexpr sexpr, 
    u32 arity
) {
    u32 count = 0;
    while (sexpr.rhs != 0 && count < arity) {
        sexpr = ctx->sexprs.ptr[sexpr.rhs];
        count += 1;
    }
    if (sexpr.rhs != 0) return errf("arity greater than %d", arity);
    if (count != arity) {
        return errf("expected arity %d but got %d", arity, count);
    }
    return 0;
}

#include "builtin_functions.c"

static error parse_eval_init(Parse_Context *ctx) {
    try (arena_alloc(
        &ctx->arena, 
        ctx->sexprs.len * sizeof(Parse_Function), 
        &ctx->functions.ptr
    ));

    try (arena_alloc(
        &ctx->arena,
        ctx->sexprs.len * sizeof(Parse_Ident),
        &ctx->idents.ptr
    ));

    slice_push(ctx->functions, ((Parse_Function){
        .name = str8("const"),
        .eval_fn = parse_builtin_const_fn,
    }));

    slice_push(ctx->functions, ((Parse_Function){
        .name = str8("run"),
        .eval_fn = parse_builtin_run_fn,
    }));

    return 0;
}

static error parse_lookup_function(
    Parse_Context *ctx, 
    Str8 name, 
    Parse_Function *out_function
) {
    for (usize i = 0; i < ctx->functions.len; i += 1) {
        Parse_Function fn = ctx->functions.ptr[i];
        if (!str8_eql(name, fn.name)) continue;
        *out_function = fn;
        return 0;
    }
    return errf("no such function '%.*s'", str8_fmt(name));
}

static error parse_function_eval(
    Parse_Context *ctx, 
    Parse_Sexpr sexpr, 
    Parse_Sexpr *out_sexpr
) {
    if (sexpr.tag.as != parse_sexpr_as_ident) return err(
        "cannot lookup function corresponding to non-identifier expression"
    );
    Str8 lexeme = parse_tok_lexeme(ctx, ctx->toks.ptr[sexpr.lhs]);
    Parse_Function fn; try (parse_lookup_function(ctx, lexeme, &fn));
    try (fn.eval_fn(ctx, sexpr, out_sexpr));
    return 0;
}

static error parse_eval_sexpr(
    Parse_Context *ctx, 
    Parse_Sexpr sexpr, 
    Parse_Sexpr *out_sexpr
) {
    switch (sexpr.tag.kind) {
        case parse_sexpr_kind_nil: return 0; break;
        case parse_sexpr_kind_atom: {
            switch ((Parse_Sexpr_As)sexpr.tag.as) {
                case parse_sexpr_as_literal: return 0; break;
                case parse_sexpr_as_symbol: return 0; break;
                case parse_sexpr_as_ident: {
                    Parse_Token ident_name_tok = ctx->toks.ptr[sexpr.lhs];
                    Str8 ident_name = parse_tok_lexeme(ctx, ident_name_tok);
                    Parse_Ident *resolved = 
                        parse_lookup_ident(ctx, ident_name);
                    if (resolved == NULL) return errf(
                        "no such identifier '%.*s'\nTODO: fn lookup here?", 
                        str8_fmt(ident_name)
                    );
                    *out_sexpr = ctx->sexprs.ptr[resolved->value_sexpr_i];
                } break;
            }
        }; break;
        case parse_sexpr_kind_pair: {
            Parse_Sexpr *first = &ctx->sexprs.ptr[sexpr.lhs];
            Parse_Sexpr *next = &ctx->sexprs.ptr[first->rhs];
            while (next->rhs != 0) {
                try (parse_eval_sexpr(ctx, *next, next));
                next = &ctx->sexprs.ptr[next->rhs];
            }
            try (parse_function_eval(ctx, *first, out_sexpr));
            out_sexpr->rhs = sexpr.rhs;
        }; break;
    }
    return 0;
}

static error parse_eval_ast(Parse_Context *ctx) {
    u32 sexpr_i = 0;
    do {
        Parse_Sexpr *sexpr = &ctx->sexprs.ptr[sexpr_i];
        try (parse_eval_sexpr(ctx, *sexpr, sexpr));
        sexpr_i = ctx->sexprs.ptr[sexpr_i].rhs;
    } while (sexpr_i != 0);
    return 0;
}

static void parse_print_idents(Parse_Context *ctx) {
    for (u32 i = 0; i < ctx->idents.len; i += 1) {
        Parse_Ident ident = ctx->idents.ptr[i];
        Str8 name = parse_tok_lexeme(ctx, ctx->toks.ptr[ident.name_tok_i]);
        Parse_Sexpr value_sexpr = ctx->sexprs.ptr[ident.value_sexpr_i];
        printf("%3d %.*s\t", i, str8_fmt(name));
        parse_print_sexpr_info(ctx, value_sexpr);
        putchar('\n');
    }
}
