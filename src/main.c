#include <locale.h>
#include <math.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <strings.h>
#include <wchar.h>
#include <wctype.h>

#define ARGS_IMPLEMENTATION
#define ARGS_BINARY_NAME "nota"
#define ARGS_BINARY_VERSION "0.3-dev"
#include "args.h"
#include "int_types.h"
#define NODE_IMPLEMENTATION
#include "node.h"
#define TOKEN_IMPLEMENTATION
#include "token.h"
#define WSTRING_IMPLEMENTATION
#include "wstring.h"

#define ANSI_IMPLEMENTATION
#include "ansi.h"


#define EX_USAGE 64
#define EX_IOERR 74

#include "helper.c"


int main(int argc, char **argv) {

    setlocale(LC_ALL, "");
    if (getenv("NOTA_NO_COLOR") == NULL && getenv("NOTA_NO_COLOUR") == NULL) ansi_stateSet();

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

    if (nocolour_flag.is_present || nocolor_flag.is_present) ansi_enabled = false;
    else if (forcecolour_flag.is_present || forcecolor_flag.is_present) ansi_enabled = true;

    FILE *input_file = fopen(positional_args[0], "r");
    if (input_file == NULL) {
        printf("%s: no such file or directory '%s'\n", ARGS_BINARY_NAME, positional_args[0]);
        return EX_IOERR;
    }


    /* @Note { Closing and opening the file again is stupid, but it seems to be the only way I can get the seek
               position to actually reset. }; */

    usize filesize = fsize(input_file);
    wchar_t filebuf[filesize];
    fclose(input_file);
    input_file = fopen(positional_args[0], "r");
    if (input_file == NULL) {
        printf("%s: no such file or directory '%s'\n", ARGS_BINARY_NAME, positional_args[0]);
        return EX_IOERR;
    }

    wint_t c;
    wchar_t wc;
    usize filebuf_len = 0;
    for (; (c = fgetwc(input_file)) != WEOF; filebuf_len++) {
        wc = (wchar_t)c;
        filebuf[filebuf_len] = wc;
    }
    filebuf[filebuf_len++] = '\0';
    fclose(input_file);

    // filebuf[] now contains the input file.

    token_SOA tokens = token_SOA_init(filesize);
    token_process(&tokens, filebuf, filebuf_len);

    return EXIT_SUCCESS;
}
