static Parse_Sexpr _sexpr_from_string(Parse_Context *ctx, Str8 str) {
    slice_push(ctx->interns, ((Parse_Intern){
        .type = parse_intern_type_string,
        .data.str = str,
    }));
    return (Parse_Sexpr){
        .tag = (Parse_Sexpr_Tag){
            .kind = parse_sexpr_kind_atom,
            .as = parse_sexpr_as_intern,
        },
        .lhs = (u32)ctx->interns.len - 1,
    };
}

static error parse_builtin_const_fn(
    void *_ctx, 
    Parse_Sexpr sexpr, 
    Parse_Sexpr *out_sexpr
) {
    Parse_Context *ctx = _ctx;
    Parse_Sexpr cdr = ctx->sexprs.ptr[sexpr.rhs];

    try (parse_ensure_arity(ctx, cdr, 2));
    (void)out_sexpr;
    printf("BUILTIN_CONST_FN: PLACEHOLDER\n");
    return 0;
}

static error parse_builtin_run_fn(
    void *_ctx, 
    Parse_Sexpr sexpr, 
    Parse_Sexpr *out_sexpr
) {
    Parse_Context *ctx = _ctx;
    Parse_Sexpr cdr = ctx->sexprs.ptr[sexpr.rhs];
    try (parse_ensure_arity(ctx, cdr, 1));

    char tmpfile_path_buf[64] = {0};
    snprintf(tmpfile_path_buf, 64, "tmp_nota%d", rand() % 100000);
    Str8 tmpfile_path = str8_from_cstr(tmpfile_path_buf);

    Str8 cmd_str8 = parse_tok_lexeme(ctx, ctx->toks.ptr[cdr.lhs]);
    char cmd_buf[2048] = {0};
    snprintf(
        cmd_buf, 
        2048,  
        "%.*s > %.*s", 
        str8_fmt(cmd_str8), 
        str8_fmt(tmpfile_path)
    );

    if (system(cmd_buf) != 0) {
        return errf("command '%s' returned non-zero exit code", cmd_buf);
    }

    Str8 cmd_output_capture; try (file_read(
        &ctx->arena, 
        tmpfile_path, 
        "rb", 
        &cmd_output_capture
    ));

    snprintf(cmd_buf, 2048, "rm %.*s", str8_fmt(tmpfile_path));
    if (system(cmd_buf) != 0) {
        return errf("failed to remove '%.*s'", str8_fmt(tmpfile_path));
    }

    *out_sexpr = _sexpr_from_string(ctx, cmd_output_capture);
    printf("BUILTIN_RUN_FN: PLACEHOLDER\n");
    return 0;
}

