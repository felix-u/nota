#include <locale.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <strings.h>
#include <sysexits.h>
#include <time.h>
#include <wchar.h>
#include <wctype.h>

#define ARGS_IMPLEMENTATION
#include "args.h"
#include "node.c"
#define WSTRING_IMPLEMENTATION
#include "wstring.h"


int main(int argc, char **argv) {

    args_SingleValReturn input_flag = args_singleValueOf(argc, argv, (char *[]){"-i", "-input", "--input"});
    if (!input_flag.is_present) {
        printf("ERROR: Must specify input file.\n");
        exit(EX_NOINPUT);
    }
    FILE *input_file = fopen(input_flag.val, "r");
    if (input_file == NULL) {
        printf("ERROR: Could not read file at \"%s\".\n", input_flag.val);
        exit(EX_IOERR);
    }

    args_SingleValReturn date_flag = args_singleValueOf(argc, argv, (char *[]){"-d", "-date", "--date"});
    if (date_flag.is_present) {
        if (!strcasecmp(date_flag.val, "isonow")) {
            time_t t = time(NULL);
            struct tm date = *localtime(&t);
            date.tm_year += 1900;
            date.tm_mon += 1;
            printf("%d-%d-%d %d:%d\n", date.tm_year, date.tm_mon, date.tm_mday, date.tm_hour, date.tm_min); // DEBUG
        }
        else {
            // @Missing { Handle custom numeric date }
            printf("ERROR: Must provide numeric date, or specify 'isonow' to use the current date.\n");
            exit(EX_USAGE);
        }
    }


    setlocale(LC_ALL, "");

    Node root;
    root.parent = NULL;
    wstring_init(&root.name, 1);
    wstring_init(&root.desc, 1);
    wstring_init(&root.date, 1);
    root.date_int = -1;
    wstring_init(&root.text, 1);
    NodeArray_init(&root.children, 1);

    wint_t c;
    wchar_t wc;
    while ((c = fgetwc(input_file)) != WEOF) {
        wc = (wchar_t)c;
        if (wc == NODE_MARKER) {
            NodeArray_append(&root.children, Node_process(input_file, &root));
        }
    }


    // DEBUG
    for (size_t i = 0; i < root.children.len; i++) {
        Node_print(root.children.nodes[i]);
    }


    Node_free(root);
    fclose(input_file);

    return EXIT_SUCCESS;
}
