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
#include "process.c"

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
    wchar_t *substr = malloc(7 * sizeof(wint_t));
    int64_t index = 0;
    int64_t from_char = 0;
    bool getting_name = false;

    while ((c = fgetwc(input_file)) != WEOF) {
        if (c == NODE_CHAR) {
            getting_name = true;
            from_char = index;
            printf("A bit of data!\n");
        }

        if (getting_name == true && isWhiteSpace(c)) {
            int substr_size = index - from_char;
            fseek(input_file, -(substr_size + 1), SEEK_CUR);
            // for (wint_t i = from_char; i < index; i++) arrput(substr, input_file[i]);
            char* result = realloc(substr, (substr_size + 1) * sizeof(wint_t));
            fgetws(substr, substr_size, input_file);
            fseek(input_file, (substr_size + 1), SEEK_CUR);

            printf("%s\n%ls\n", result, substr);
        }

        index++;
    }


    arrfree(root);
    free(substr);
    fclose(input_file);
    return EXIT_SUCCESS;
}
