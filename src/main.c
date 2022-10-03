#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <sysexits.h>
#include <wchar.h>
#include <wctype.h>
#include <locale.h>

#include "args.c"
#include "node.c"

#ifndef STB_DS_IMPLEMENTATION
#define STB_DS_IMPLEMENTATION
#include "../deps/stb_ds-v0.67/stb_ds.h"
#endif


int main(int argc, char **argv) {

    // @Feature { Run on all files in current directory, not just one manually specified file }

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

    Node root;
    root = processNode(&root, input_file);

    // // DEBUG
    // for (int i = 0; i < arrlen(root.children); i++) {
    //     printls(root.children[i].text);
    //     putchar('\n');
    // }

    fclose(input_file);
    return EXIT_SUCCESS;
}
