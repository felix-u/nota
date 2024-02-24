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
    *out_sexpr = _sexpr_from_string(ctx, str8("PLACEHOLDER"));
    out_sexpr->rhs = sexpr.rhs;
    printf("BUILTIN_RUN_FN: PLACEHOLDER\n");
    return 0;
}

