#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <sysexits.h>
#include <wchar.h>
#include <wctype.h>
#include <locale.h>

#define ARGS_IMPLEMENTATION
#include "args.h"

#include "node.c"

#define STB_DS_IMPLEMENTATION
#include "../deps/stb_ds-v0.67/stb_ds.h"


int main(int argc, char **argv) {

    // @Feature { Run on all files in current directory, not just one manually specified file }

    char *input_path = args_singleValueOf(argc, argv, (char *[]){"-i", "--input", "-input"});
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

    // @Missing { We need to go through all nodes in the arr_arena and free their data, children first. }

    deallocNode(&root);
    fclose(input_file);
    return EXIT_SUCCESS;
}
