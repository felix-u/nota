static void print_token(Parse_Context *ctx, Parse_Token tok) {
    Str8 lexeme = parse_tok_lexeme(ctx, tok);
    Str8 tok_kind_string = parse_string_from_token_kind(tok.kind);
    printf("%.*s '%.*s'", str8_fmt(tok_kind_string), str8_fmt(lexeme));
}

static void print_tokens(Parse_Context *ctx) {
    printf("Tokens:\n");
    Parse_Token_Slice toks = ctx->toks;
    for (u32 i = 0; i < toks.len; i += 1) {
        printf("%3d ", i);
        print_token(ctx, toks.ptr[i]);
        putchar('\n');
    }
}

static Str8 _string_from_sexpr_kind(Parse_Sexpr_Kind kind) {
    switch (kind) {
        case parse_sexpr_kind_nil : return str8("Sexpr<NIL>");  break;
        case parse_sexpr_kind_atom: return str8("Sexpr<atom>"); break;
        case parse_sexpr_kind_pair: return str8("Sexpr<list>"); break;
    }
}

static Str8 _string_from_sexpr_as(Parse_Sexpr_As as) {
    switch (as) {
        case parse_sexpr_as_ident:  return str8("(ident)");  break;
        case parse_sexpr_as_literal: return str8("(literal)"); break;
        case parse_sexpr_as_symbol:  return str8("(symbol)");  break;
    }
}

static void print_literal(Parse_Literal literal) {
    switch (literal.type) {
        case parse_literal_type_string: {
            printf("literal<string> '%.*s'", str8_fmt(literal.data.str));
        }; break;
    }
}

static void print_sexpr_info(Parse_Context *ctx, Parse_Sexpr sexpr) {
    Str8 sexpr_kind_string = _string_from_sexpr_kind(sexpr.tag.kind);
    Str8 sexpr_as_string = _string_from_sexpr_as(sexpr.tag.as);
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
                print_token(ctx, ctx->toks.ptr[sexpr.lhs]);
            } break;
            case parse_sexpr_as_literal: {
                print_literal(ctx->literals.ptr[sexpr.lhs]);
            } break;
        }
    }
}

static void print_sexpr(
    Parse_Context *ctx, 
    Parse_Sexpr sexpr, 
    usize indent_level
) {
    Parse_Sexpr_Slice sexprs = ctx->sexprs;
    for (usize i = 0; i < indent_level; i += 1) printf("    ");

    switch (sexpr.tag.kind) {
        case parse_sexpr_kind_nil: printf("<nil>\n"); break;
        case parse_sexpr_kind_atom: {
            print_sexpr_info(ctx, sexpr);
            putchar('\n');
        } break;
        case parse_sexpr_kind_pair: {
            print_sexpr_info(ctx, sexpr);
            putchar('\n');
            for (
                u32 sexpr_i = sexpr.lhs; 
                sexpr_i != 0; 
                sexpr_i = sexprs.ptr[sexpr_i].rhs
            ) {
                print_sexpr(ctx, sexprs.ptr[sexpr_i], indent_level + 1);
            }
        } break;
    }
}

static void print_ast(Parse_Context *ctx) {
    printf("S-expressions:\n");
    for (u32 i = 0; i < ctx->sexprs.len; i += 1) {
        printf("%3d ", i);
        print_sexpr_info(ctx, ctx->sexprs.ptr[i]);
        putchar('\n');
    }
    printf("AST:\n");
    u32 sexpr_i = 0;
    do {
        print_sexpr(ctx, ctx->sexprs.ptr[sexpr_i], 0);
        sexpr_i = ctx->sexprs.ptr[sexpr_i].rhs;
    } while (sexpr_i != 0);
}

static void print_idents(Parse_Context *ctx) {
    printf("Identifiers:\n");
    for (u32 i = 0; i < ctx->idents.len; i += 1) {
        Parse_Ident ident = ctx->idents.ptr[i];
        Str8 name = parse_tok_lexeme(ctx, ctx->toks.ptr[ident.name_tok_i]);
        Parse_Sexpr value_sexpr = ctx->sexprs.ptr[ident.value_sexpr_i];
        printf("%3d %.*s\t", i, str8_fmt(name));
        print_sexpr_info(ctx, value_sexpr);
        putchar('\n');
    }
}
