#include "base.h"

// #define ARGS_IMPLEMENTATION
// #define ARGS_BINARY_NAME "nota"
// #define ARGS_BINARY_VERSION "0.4-dev"
// #include "args.h"

int main(int argc, char **argv) {
    int exitcode = 1;

    arena arena = { 0 };
    arena_init(&arena);
    if (!arena.mem) goto defer;

    // Args_Flag flag_help = { .kind = ARGS_KIND_HELP };
    // Args_Flag flag_version = { .kind = ARGS_KIND_VERSION };
    // Args_Def args_def = {
    //     .arg_list = arg_list_from(argc, argv),
    //     .flags = (flag_slice)slice_lit({
    //         &flag_help,
    //         &flag_version,
    //     }),
    //     .info = {
    //         .desc = str8_lit("parser for the nota langauge"),
    //         .usage = str8_lit("<file> [options]"),
    //         .version = str8_lit("0.4-dev"),
    //     },
    // };

    (void)argc;
    const str8 path = str8_from_cstr(argv[1]);

    str8 filebuf = file_read(&arena, path);
    if (!filebuf.ptr || !filebuf.len) {
        fprintf(stderr, "error: unable to open '%s'\n", path.ptr);
        goto defer;
    }

    printf("opened '%s' of length %zu:\n%s", 
            path.ptr, filebuf.len, filebuf.ptr);

    exitcode = 0;

    defer:
    arena_deinit(&arena);
    return exitcode;
}
