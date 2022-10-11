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
    wstring name; wstring_init(&name, 1);
    wstring desc; wstring_init(&desc, 1);
    wstring date; wstring_init(&date, 1);
    wstring text; wstring_init(&text, 1);
    bool getting_name = false;
    bool getting_desc = false;
    bool getting_date = false;
    bool getting_text = false;

    wint_t c;
    wchar_t wc;
    while ((c = fgetwc(input_file)) != WEOF) {

        wc = (wchar_t)c;

        if (getting_name == true) {
            if (wc == DLM_DESC.beg) {
                getting_name = false;
                getting_desc = true;
            }
            else if (wc == DLM_DATE.beg) {
                getting_name = false;
                getting_date = true;
            }
            else if (wc == DLM_TEXT.beg) {
                getting_name = false;
                getting_text = true;
            }
            else wstring_append(&name, c);
        }
        else if (getting_desc == true) {
            if (wc == DLM_DESC.end) getting_desc = false;
            else wstring_append(&desc, c);
        }
        else if (getting_date == true) {
            if (wc == DLM_DATE.end) getting_date = false;
            else wstring_append(&date, c);
        }
        else if (getting_text == true) {
            if (wc == DLM_TEXT.end) {
                getting_text = false;
                break;
            }
            else wstring_append(&text, c);
        }

        if (wc == NODE_MARKER) getting_name = true;
        else if (wc == DLM_DESC.beg) getting_desc = true;
        else if (wc == DLM_DATE.beg) getting_date = true;
        else if (wc == DLM_TEXT.beg) getting_text = true;
    }

    printf("Name: %ls\n", name.wstr);
    printf("Desc: %ls\n", desc.wstr);
    printf("Date: %ls\n", date.wstr);
    printf("Text: %ls\n", text.wstr);

    free(name.wstr);
    free(desc.wstr);
    free(date.wstr);
    free(text.wstr);
    fclose(input_file);
    return EXIT_SUCCESS;
}
