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
"      --debug\n"
"        Print debug information\n"
"  -h, --help\n"
"        Print this help and exit\n"
"      --version\n"
"        Print version information and exit\n"
);

#include "parse.c"

int main(int argc, char **argv) {
    int result = 0;
    if (argc == 1) {
        printf("%.*s", str8_fmt(help_text));
        return 1;
    }

    Args_Flag debug_flag = { .name = str8("debug") };
    Args_Flag help_flag_short = { .name = str8("h") };
    Args_Flag help_flag_long = { .name = str8("help") };
    Args_Flag version_flag = { .name = str8("version") };
    Args_Flag *flags[] = {
        &debug_flag,
        &help_flag_short, &help_flag_long,
        &version_flag,
    };
    Slice_Args_Flag_ptr flags_slice = slice(flags);
    Args_Desc args_desc = {
        .exe_kind = args_kind_single_pos,
        .flags = flags_slice,
    };
    if (args_parse(argc, argv, &args_desc) != 0) return 1;

    if (help_flag_short.is_present || help_flag_long.is_present) {
        printf("%.*s", str8_fmt(help_text));
        return 0;
    }

    if (version_flag.is_present) {
        printf("%.*s", str8_fmt(version_text));
        return 0;
    }
    
    Context ctx = { 
        .arena = arena_init(16 * 1024 * 1024),
        .path = (char *)args_desc.single_pos.ptr,
    };

    ctx.bytes = file_read(&ctx.arena, ctx.path, "rb");
    if (ctx.bytes.len >= UINT32_MAX) {
        usize max_mb = UINT32_MAX / 1024 / 1024;
        errf("file '%s' exceeds max size %zu megabytes", ctx.path, max_mb);
        ctx.bytes = (Str8){0};
    }
    if (debug_flag.is_present && ctx.bytes.len > 0) {
        printf("File:\\\n%.*s\\ File end\n", str8_fmt(ctx.bytes));
    }

    ctx.tokens = tokens_from_bytes(&ctx);
    ctx.nodes = nodes_from_tokens(&ctx);

    arena_deinit(&ctx.arena);
    return result;
}

