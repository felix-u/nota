#include <stdlib.h>
#include <stdio.h>
#include <wchar.h>
#include <wctype.h>
#include <locale.h>

#include <sysexits.h>

#define ARGS_IMPLEMENTATION
#include "args.h"

#include "node.c"


int main(int argc, char **argv) {

    char *input_path = args_singleValueOf(argc, argv, (char *[3]){"-i", "-input", "--input"});
    if (input_path == NULL) {
        printf("ERROR: Must specify input file.\n");
        exit(EX_NOINPUT);
    }
    FILE *input_file = fopen(input_path, "r");
    if (input_file == NULL) {
        printf("ERROR: Could not read file at \"%s\".\n", input_path);
        exit(EX_IOERR);
    }

    setlocale(LC_ALL, "");
    wint_t c;
    while ((c = fgetwc(input_file)) != WEOF) {
        putwchar(c);
    }

    fclose(input_file);
    return EXIT_SUCCESS;
}
