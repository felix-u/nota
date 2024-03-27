const Parse_Sexpr nil_sexpr = {0};

static Parse_Sexpr _sexpr_from_string(Parse_Context *ctx, Str8 str) {
    slice_push(ctx->literals, ((Parse_Literal){
        .type = parse_literal_type_string,
        .data.str = str,
    }));
    return (Parse_Sexpr){
        .tag = (Parse_Sexpr_Tag){
            .kind = parse_sexpr_kind_atom,
            .as = parse_sexpr_as_literal,
        },
        .lhs = (u32)ctx->literals.len - 1,
    };
}

static Parse_Sexpr parse_builtin_const_fn(void *_ctx, Parse_Sexpr sexpr) {
    Parse_Context *ctx = _ctx;
    Parse_Sexpr cdr = ctx->sexprs.ptr[sexpr.rhs];

    if (!parse_ensure_arity(ctx, cdr, 2)) return nil_sexpr;

    Str8 ident_name = parse_tok_lexeme(ctx, ctx->toks.ptr[cdr.lhs]);
    if (parse_lookup_ident(ctx, ident_name) != 0) {
        errf("symbol '%.*s' already exists", str8_fmt(ident_name));
        return nil_sexpr;
    }

    slice_push(ctx->idents, ((Parse_Ident){
        .name_tok_i = cdr.lhs,
        .value_sexpr_i = cdr.rhs,
    }));

    return nil_sexpr;
}

static Parse_Sexpr parse_builtin_run_fn(void *_ctx, Parse_Sexpr sexpr) {
    Parse_Context *ctx = _ctx;
    Parse_Sexpr cdr = ctx->sexprs.ptr[sexpr.rhs];
    if (!parse_ensure_arity(ctx, cdr, 1)) return nil_sexpr;

    char tmpfile_path_buf[64] = {0};
    snprintf(tmpfile_path_buf, 64, "/tmp/tmp_nota%d", rand() % 100000);
    Str8 tmpfile_path = str8_from_cstr(tmpfile_path_buf);

    Parse_Literal cmd_str_literal = ctx->literals.ptr[cdr.lhs];
    if (cmd_str_literal.type != parse_literal_type_string) {
        err("expected string literal");
        return nil_sexpr;
    }

    char cmd_buf[2048] = {0};
    snprintf(
        cmd_buf, 
        2048,  
        "%.*s > %.*s", 
        str8_fmt(cmd_str_literal.data.str), 
        str8_fmt(tmpfile_path)
    );

    if (system(cmd_buf) != 0) {
        errf("command '%s' returned non-zero exit code", cmd_buf);
        return nil_sexpr;
    }

    Str8 cmd_output_capture = file_read(&ctx->arena, tmpfile_path, "rb");

    snprintf(cmd_buf, 2048, "rm %.*s", str8_fmt(tmpfile_path));
    if (system(cmd_buf) != 0) {
        errf("failed to remove '%.*s'", str8_fmt(tmpfile_path));
        return nil_sexpr;
    }

    return _sexpr_from_string(ctx, cmd_output_capture);
}

