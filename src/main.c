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

const wint_t NODE_CHAR = '@';
const Delimiter DESC_DLM = { '(', ')' };
const Delimiter DATE_DLM = { '[', ']' };
const Delimiter NODE_DLM = { '{', '}' };


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

    Node *root = NULL;
    Node *current_node = root;

    wint_t c;
    int64_t index = 0;

    wint_t *name = NULL;
    wint_t *desc = NULL;
    wint_t *date = NULL;
    wint_t *text = NULL;
    bool getting_name = false;
    bool getting_desc = false;
    bool getting_date = false;
    bool getting_text = false;

    while ((c = fgetwc(input_file)) != WEOF) {

        if (getting_name == true) {
            if (isWhiteSpace(c) || c == DESC_DLM.beg || c == DATE_DLM.beg || c == NODE_DLM.beg) getting_name = false;
            else arrput(name, c);
        }

        if (getting_desc == true) {
            if (c == DESC_DLM.end) getting_desc = false;
            else arrput(desc, c);
        }

        if (c == NODE_CHAR) getting_name = true;
        else if (c == DESC_DLM.beg) getting_desc = true;

        index++;
    }

    // DEBUG
    for (int i = 0; i < arrlen(name); i++) printf("%lc", name[i]);
    putchar('\n');
    for (int i = 0; i < arrlen(desc); i++) printf("%lc", desc[i]);
    putchar('\n');

    arrfree(root);
    arrfree(name);
    arrfree(desc);
    arrfree(date);
    arrfree(text);
    fclose(input_file);
    return EXIT_SUCCESS;
}
