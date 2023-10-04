#include "base.h"

#include "token.h"

#define ARGS_IMPLEMENTATION
#define ARGS_BINARY_NAME "nota"
#define ARGS_BINARY_VERSION "0.4-dev"
#include "args.h"

int main(int argc, char **argv) {
    int exitcode = 1;

    arena arena = { 0 };
    FILE *fp = NULL;
    int filesize = 0;
    u8 *filebuf = NULL;

    args_Flag *flags[] = {
        &ARGS_HELP_FLAG,
        &ARGS_VERSION_FLAG,
    };

    const usize flags_count = sizeof(flags) / sizeof(flags[0]);
    usize positional_num = 0;
    const usize positional_cap = 256;
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

    const char *path = positional_args[0];

    if (!(fp = fopen(path, "r"))) {
        fprintf(stderr, "error: failed to open '%s'\n", path);
        goto defer;
    } 
    
    fseek(fp, 0L, SEEK_END);
    filesize = ftell(fp);
    arena.cap = filesize + 1;

    if (!arena_init(&arena) || 
        !(filebuf = arena_alloc(&arena, filesize + 1))
    ) {
        fprintf(stderr, "error: memory allocation failure\n");
        goto defer;
    }

    fseek(fp, 0L, SEEK_SET);
    filesize = fread(filebuf, sizeof(char), filesize, fp);

    if (ferror(fp)) {
        fprintf(stderr, "error: file error '%s'\n", path);
        goto defer;
    }

    fclose(fp);
    fp = NULL;

    filebuf[filesize] = '\0';

    printf("opened '%s':\n%s", path, filebuf);

    exitcode = 0;

    defer:
    if (fp) fclose(fp);
    arena_deinit(&arena);
    return exitcode;
}
