#include <math.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>

#define  ARGS_IMPLEMENTATION
#define  ARGS_BINARY_NAME    "nota"
#define  ARGS_BINARY_VERSION "0.4-dev"
#include "args.h"
#include "better_int_types.h"

#define ARR_TYPE int
#include "arrays.inc"
#undef ARR_TYPE

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

    args_Flag *flags[] = {
        &ARGS_HELP_FLAG,
        &ARGS_VERSION_FLAG,
    };

    usize positional_num = 0;
    const usize positional_cap = 256;
    char *positional_args[positional_cap];
    int args_return = args_proc((args_Proc_Args) {
        argc, argv, 
        .flags_count = sizeof(flags) / sizeof(flags[0]),
        flags,
        &positional_num, positional_args,
        .usage_description = "parser for simple node notation",
        .positional_expects = ARGS_EXPECTS_FILE,
        .positional_type = ARGS_POSITIONAL_SINGLE, 
        positional_cap,
    });
    if (args_return != ARGS_RETURN_CONTINUE) return args_return;

    FILE *input_file = fopen(positional_args[0], "r");
    if (input_file == NULL) {
        printf("%s: no such file or directory '%s'\n", ARGS_BINARY_NAME, positional_args[0]);
        return EX_IOERR;
    }


    /* @Note "Closing and opening the file again is stupid, but it seems to be the only way I can get the seek
       position to actually reset."; */

    usize filesize = fsize(input_file);
    char filebuf[filesize + 1];
    memset(filebuf, 0, sizeof(*filebuf) * filesize);
    fclose(input_file);
    input_file = fopen(positional_args[0], "r");
    if (input_file == NULL) {
        printf("%s: no such file or directory '%s'\n", ARGS_BINARY_NAME, positional_args[0]);
        return EX_IOERR;
    }

    for (usize i = 0; i < filesize; i++) {
        filebuf[i] = fgetc(input_file);
    }
    filebuf[filesize] = '\0';
    fclose(input_file);

    // filebuf[] now contains the input file.
    
    // // DEBUG
    // int *inta = intarr_init(2);
    // for (usize i = 0; i < 200; i++) {
    //     intarr_push(&inta, (i + 1)*(i + 1));
    //     printf("%ld/%ld (capacity %ld)\t%d\n", i + 1, arr_len(inta), arr_cap(inta), inta[i]);
    // }
    // intarr_free(inta);

    // token_SOA tokens = token_SOA_init(filesize);
    // token_process(&tokens, filebuf, filesize);

    // for (usize i = 0; i < tokens.len; i++) {
    //     printf("%ld:%ld\n", tokens.row[i], tokens.col[i]);
    //     printf("TOKEN: %c\n", tokens.tok[i]);
    //     for (usize j = tokens.lexeme_start[i]; j <= tokens.lexeme_end[i]; j++) {
    //         putchar(filebuf[j]);
    //     }
    //     printf("\n\n");
    // }

    // token_SOA_free(tokens);
    return EXIT_SUCCESS;
}
