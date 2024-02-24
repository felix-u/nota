#include "base.c"

#include "args.c"

#define version_lit "0.4-dev"
const Str8 version_text = str8("nota version " version_lit "\n");

const Str8 help_text = str8(
"nota (version " version_lit ")\n"
"\n"
"Usage: nota <file>\n"
"\n"
"Options:\n"
"  -h, --help\n"
"        Print this help and exit\n"
"      --version\n"
"        Print version information and exit\n"
);

#include "parse.c"

static error main_wrapper(Parse_Context *ctx) {
    try (arena_init(&ctx->arena, 16 * 1024 * 1024));

    Args_Flag help_flag_short = { .name = str8("h") };
    Args_Flag help_flag_long = { .name = str8("help") };
    Args_Flag version_flag = { .name = str8("version") };
    Args_Flag *flags[] = {
        &help_flag_short, &help_flag_long,
        &version_flag,
    };
    Args_Desc args_desc = {
        .exe_kind = args_kind_single_pos,
        .flags = slice(flags),
    };
    try (args_parse(ctx->argc, ctx->argv, &args_desc));

    if (help_flag_short.is_present || help_flag_long.is_present) {
        printf("%.*s", str8_fmt(help_text));
        return 0;
    }

    if (version_flag.is_present) {
        printf("%.*s", str8_fmt(version_text));
        return 0;
    }

    ctx->path = args_desc.single_pos;
    try (file_read(&ctx->arena, ctx->path, "rb", &ctx->bytes));
    if (ctx->bytes.len >= UINT32_MAX) {
        usize max_mb = UINT32_MAX / 1024 / 1024;
        return errf(
            "file '%.*s' exceeds max size %zu megabytes",
            str8_fmt(ctx->path), max_mb
        );
    }
    printf("=== FILE BEGIN\\\n%.*s=== FILE END\n", str8_fmt(ctx->bytes));

    try (parse_lex(ctx));
    printf("=== TOKENS BEGIN\n");
    parse_print_tokens(ctx);
    printf("=== TOKENS END\n");

    try (parse_ast_from_toks(ctx));
    printf("=== AST BEGIN\n");
    parse_print_ast(ctx);
    printf("=== AST END\n");

    printf("=== EVAL BEGIN\n");
    try (parse_eval_init(ctx));
    try (parse_eval_ast(ctx));
    printf("=== EVAL END\n");

    printf("=== AST BEGIN\n");
    parse_print_ast(ctx);
    printf("=== AST END\n");

    return 0;
}

int main(int argc, char **argv) {
    if (argc == 1) {
        printf("%.*s", str8_fmt(help_text));
        return 1;
    }

    Parse_Context ctx = { .argc = argc, .argv = argv };
    error e = main_wrapper(&ctx);
    arena_deinit(&ctx.arena);
    return e;
}

