#include <locale.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
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


double cstrToDouble(char *cstr);


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
        double user_date = 0;
        if (date_flag.val == NULL) {
            printf("ERROR: Must provide numeric date, or specify 'isonow' to use the current date.\n");
            fclose(input_file);
            exit(EX_USAGE);
        }
        else if (!strcasecmp(date_flag.val, "isonow")) {
            time_t t = time(NULL);
            struct tm date = *localtime(&t);
            date.tm_year += 1900;
            date.tm_mon += 1;
            // The max char length of the formatted string below, courtesy of the compiler
            const size_t date_cstr_size_cap = 33;
            char date_cstr[date_cstr_size_cap];

            snprintf(date_cstr, date_cstr_size_cap, "%04d%02d%02d.%02d%02d\n",
                    (int16_t)date.tm_year,
                    (int16_t)date.tm_mon,
                    (int16_t)date.tm_mday,
                    (int16_t)date.tm_hour,
                    (int16_t)date.tm_min);
            user_date = atof(date_cstr);
        }
        else {
            user_date = cstrToDouble(date_flag.val);
            if (user_date == 0) {
                printf("ERROR: Please provide valid non-zero date in ISO format.\n");
                fclose(input_file);
                exit(EX_USAGE);
            }
        }
    }


    setlocale(LC_ALL, "");

    Node root;
    root.parent = NULL;
    wstring_init(&root.name, 1);
    wstring_init(&root.desc, 1);
    wstring_init(&root.date, 1);
    root.date_num = -1;
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


double cstrToDouble(char *cstr) {
    double ret = 0;

    size_t str_len = strlen(cstr);
    char cbuf_int[str_len];
    bool found_decimal = false;
    size_t int_idx = 0;
    size_t int_cstr_idx = 0;

    for (; int_cstr_idx < str_len; int_cstr_idx++) {
        char c = cstr[int_cstr_idx];
        if (c >= '0' && c <= '9') {
            cbuf_int[int_idx] = cstr[int_cstr_idx];
            int_idx++;
        }
        else if (c == '.' || c == ',' || c == ' ') {
            found_decimal = true;
            break;
        }
    }
    ret += atof(cbuf_int);

    if (found_decimal) {
        char cbuf_dec[str_len - int_cstr_idx];
        size_t dec_idx = 0;
        for (size_t dec_cstr_idx = int_cstr_idx + 1; dec_cstr_idx < str_len; dec_cstr_idx++) {
            char c = cstr[dec_cstr_idx];
            if (c >= '0' && c <= '9') {
                cbuf_dec[dec_idx] = cstr[dec_cstr_idx];
                dec_idx++;
            }
        }
        float dec_add = atof(cbuf_dec);
        for (size_t i = 0; i < dec_idx; i++) {
            dec_add /= 10;
        }
        ret += dec_add;
    }

    return ret;

}
