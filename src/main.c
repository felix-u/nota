#include "base.h"

#define ARGS_IMPLEMENTATION
#define ARGS_BINARY_NAME "nota"
#define ARGS_BINARY_VERSION "0.4-dev"
#include "args.h"

int main(int argc, char **argv) {
    int exitcode = 1;

    arena arena = { 0 };
    arena_init(&arena);
    if (!arena.mem) goto defer;

    args_Flag *flags[] = {
        &ARGS_HELP_FLAG,
        &ARGS_VERSION_FLAG,
    };

    const usize flags_count = sizeof(flags) / sizeof(flags[0]);
    usize positional_num = 0;
    #define positional_cap 256
    char *positional_args[positional_cap];
    int args_return = args_proc((args_Proc_Args){
        argc, argv,
        flags_count, flags,
        &positional_num, positional_args,
        .usage_description = "nota language parser",
        .positional_expects = ARGS_EXPECTS_FILE,
        .positional_type = ARGS_POSITIONAL_SINGLE,
        positional_cap,
    });
    if (args_return != ARGS_RETURN_CONTINUE) {
        exitcode = args_return;
        goto defer;
    }

    const str8 path = str8_from_cstr(positional_args[0]);

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
