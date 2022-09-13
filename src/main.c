#include <stdlib.h>
#include <stdio.h>
#include <sysexits.h>

#include "args.c"


int main(int argc, char **argv) {

    // @Feature Run on all files in current directory, not just one manually specified file @Feature
    char **input_arg = (char *[]){"-i", "--input"};
    char *input_path = args_singleValueOf(argc, argv, input_arg);
    if (input_path == NULL) {
        printf("ERROR: Must provide path to file.\n");
        exit(EX_USAGE);
    }

    return EXIT_SUCCESS;
}
