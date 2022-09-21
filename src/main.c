#include <stdlib.h>
#include <stdio.h>
#include <sysexits.h>
#include <wchar.h>
#include <wctype.h>
#include <locale.h>

#include "args.c"


int main(int argc, char **argv) {

    // @Feature Run on all files in current directory, not just one manually specified file @Feature

    char **input_arg = (char *[]){"-i", "--input"};
    char *input_path = args_singleValueOf(argc, argv, input_arg);
    if (input_path == NULL) {
        printf("ERROR: Must provide path to file.\n");
        exit(EX_USAGE);
    }

    FILE *input_file = fopen(input_path, "r");
    if (input_file == NULL) {
        printf("ERROR: Unable to find file \"%s\".\n", input_path);
        exit(EX_NOINPUT);
    }

    setlocale(LC_ALL, "");
    wint_t c;
    // âñ大
    while ((c = fgetwc(input_file)) != WEOF) {
        printf("%lc", c);
    }


    fclose(input_file);
    return EXIT_SUCCESS;
}
