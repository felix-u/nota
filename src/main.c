#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <sysexits.h>
#include <wchar.h>
#include <wctype.h>
#include <locale.h>

#define STB_DS_IMPLEMENTATION
#include "../deps/stb_ds-v0.67/stb_ds.h"

#include "args.c"
#include "node.c"

const wint_t NODE_CHAR = L'@';


int main(int argc, char **argv) {

    // @Feature Run on all files in current directory, not just one manually specified file @Feature

    char *input_path = args_singleValueOf(argc, argv, (char *[2]){"-i", "--input"});
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
    Node *root = NULL;

    // Iterate over file characters
    wint_t c;
    int64_t index = 0;
    while ((c = fgetwc(input_file)) != WEOF) {
        if (c == NODE_CHAR) {
            printf("A bit of data!\n");
        }

        index++;
    }


    arrfree(root);
    fclose(input_file);
    return EXIT_SUCCESS;
}
