#include <math.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <strings.h>

#define  ARGS_IMPLEMENTATION
#define  ARGS_BINARY_NAME    "nota"
#define  ARGS_BINARY_VERSION "0.4-dev"
#include "args.h"
#include "better_int_types.h"

#define EX_USAGE 64
#define EX_IOERR 74

#ifdef UNITY_BUILD
    #include "helper.c"
    #include "token.c"
#else
    #include "helper.h"
    #include "token.h"
#endif


int main(int argc, char **argv) {

    args_Flag nocolour_flag = {
        false, "no-colour",
        "disables colour in output. This will also occur if TERM=dumb, \n"
        "NO_COLO(U)R or NOTA_NO_COLO(U)R is set, or the output is piped to a file",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };
    args_Flag nocolor_flag = {
        false, "no-color",
        "equivalent to the above",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };
    args_Flag forcecolour_flag = {
        false, "force-colour",
        "forces colour in output. This will override TERM=dumb, \n"
        "NO_COLO(U)R, and NOTA_NO_COLO(U)R",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };
    args_Flag forcecolor_flag = {
        false, "force-color",
        "equivalent to the above",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };

    args_Flag *flags[] = {
        &nocolour_flag,
        &nocolor_flag,
        &forcecolour_flag,
        &forcecolor_flag,
        &ARGS_HELP_FLAG,
        &ARGS_VERSION_FLAG,
    };

    const usize flags_count = sizeof(flags) / sizeof(flags[0]);
    usize positional_num = 0;
    const usize positional_cap = 256;
    char *positional_args[positional_cap];
    int args_return = args_process(argc, argv, "parser for simple node notation", flags_count, flags,
                                   &positional_num, positional_args, ARGS_EXPECTS_FILE, ARGS_POSITIONAL_SINGLE,
                                   positional_cap);
    if (args_return != ARGS_RETURN_CONTINUE) return args_return;

    FILE *input_file = fopen(positional_args[0], "r");
    if (input_file == NULL) {
        printf("%s: no such file or directory '%s'\n", ARGS_BINARY_NAME, positional_args[0]);
        return EX_IOERR;
    }


    /* @Note { Closing and opening the file again is stupid, but it seems to be the only way I can get the seek
               position to actually reset. }; */

    usize filesize = fsize(input_file);
    char filebuf[filesize];
    memset(filebuf, 0, sizeof(*filebuf) * filesize);
    fclose(input_file);
    input_file = fopen(positional_args[0], "r");
    if (input_file == NULL) {
        printf("%s: no such file or directory '%s'\n", ARGS_BINARY_NAME, positional_args[0]);
        return EX_IOERR;
    }

    usize filebuf_len = 0;
    for (char c = 0; (c = fgetc(input_file)) != EOF; filebuf_len++) {
        filebuf[filebuf_len] = c;
    }
    filebuf[filebuf_len++] = '\0';
    fclose(input_file);

    // filebuf[] now contains the input file.

    token_SOA tokens = token_SOA_init(filesize);
    token_process(&tokens, filebuf, filebuf_len);

    for (usize i = 0; i < tokens.len; i++) {
        printf("%ld:%ld\n", tokens.row[i], tokens.col[i]);
        printf("TOKEN: %c\n", tokens.tok[i]);
        for (usize j = tokens.lexeme_start[i]; j <= tokens.lexeme_end[i]; j++) {
            putchar(filebuf[j]);
        }
        printf("\n\n");
    }

    token_SOA_free(tokens);
    return EXIT_SUCCESS;
}
