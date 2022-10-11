#include <stdbool.h>
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

    Node root;
    NodeArray_init(&root.children, 1);

    wint_t c;
    wchar_t wc;
    while ((c = fgetwc(input_file)) != WEOF) {

        wc = (wchar_t)c;

        if (wc == NODE_MARKER) {
            NodeArray_append(&root.children, Node_process(input_file, &root));
        }
    }


    // Node_print(root);
    for (size_t i = 0; i < root.children.len; i++) {
        // printf("\n\n NODE \n\n");
        Node_print(root.children.nodes[i]);
    }

    // free(name.wstr);
    // free(desc.wstr);
    // free(date.wstr);
    // free(text.wstr);
    fclose(input_file);
    return EXIT_SUCCESS;
}
