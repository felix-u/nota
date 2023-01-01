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
#define ARGS_BINARY_NAME "nota"
#define ARGS_BINARY_VERSION "0.1-dev"
#include "args.h"

#include "node.c"

#define WSTRING_IMPLEMENTATION
#include "wstring.h"


double cstrToDouble(char *cstr);
void nodeptrsInBuf(Node **ptrbuf, Node *node, size_t *idx);


bool must_sort_nodes = false;
bool must_print_tree = false;


int main(int argc, char **argv) {

    setlocale(LC_ALL, "");

    // @Missing { Unicode support in args.h }
    args_Flag date_flag = {
        'd', "date",
        "specified date (uses current date if not given)",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_SINGLE_OPT, ARGS_EXPECTS_STRING
    };
    args_Flag sort_flag = {
        's', "sort",
        "sorting options",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_MULTI_OPT, ARGS_EXPECTS_STRING
    };
    args_Flag flags[] = {
        date_flag,
        sort_flag,
        ARGS_HELP_FLAG,
        ARGS_VERSION_FLAG,
    };
    const size_t flags_count = (sizeof flags) / (sizeof flags[0]);
    size_t positional_num = 0;
    const size_t positional_cap = 256;
    char *positional_args[positional_cap];
    int args_return = args_process(argc, argv, "a parser for a simple node notation", flags_count, flags,
                                   &positional_num, positional_args, ARGS_EXPECTS_FILE, ARGS_POSITIONAL_SINGLE,
                                   positional_cap);
    if (args_return != ARGS_RETURN_CONTINUE) return args_return;

    FILE *input_file = fopen(positional_args[0], "r");
    if (input_file == NULL) {
        printf("ERROR: Could not read file at \"%s\".\n", positional_args[0]);
        exit(EX_IOERR);
    }

    double user_date = 0;

    if (!date_flag.is_present && !sort_flag.is_present) {
        // Print nodes without altering order if a file is given with no flags
        must_print_tree = true;
    }
    else if ((date_flag.is_present && !sort_flag.is_present) || (!date_flag.is_present && sort_flag.is_present)) {
        printf("ERROR: Must use 'sort' flag in conjuction with 'date' flag.\n");
        fclose(input_file);
        exit(EX_USAGE);
    }
    else if (date_flag.is_present && sort_flag.is_present) {

        must_sort_nodes = true;

        if (!strcasecmp(date_flag.opts[0], "now")) {
            time_t t = time(NULL);
            struct tm date = *localtime(&t);
            date.tm_year += 1900;
            date.tm_mon += 1;
            // 33 is the max possible char length of the formatted string below, courtesy of the compiler
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
            user_date = cstrToDouble(date_flag.opts[0]);
            if (user_date == 0) {
                printf("ERROR: Please provide valid non-zero date in ISO format.\n");
                fclose(input_file);
                exit(EX_USAGE);
            }
        }

        // @Missing { More sorting options, and polish }

        if (sort_flag.opts_num == 0) {
            printf("ERROR: Must provide sort option (run qaml with the --help flag for usage details).\n");
            fclose(input_file);
            exit(EX_USAGE);
        }
        else if (!strcasecmp(sort_flag.opts[0], "upcoming")) {
            // -d [date] -s upcoming
            // @Missing {}
            printf("NOT IMPLEMENTED: --sort upcoming\n\n");
        }
        else {
            printf("ERROR: Please provide a valid option to the 'sort' flag.\n");
            fclose(input_file);
            exit(EX_USAGE);
        }
    }


    NodeArray all_nodes;
    NodeArray_init(&all_nodes, 1);
    Node root;
    root.parent = NULL;
    wstring_init(&root.name, 1);
    wstring_init(&root.desc, 1);
    wstring_init(&root.date, 1);
    root.date_num = -1;
    wstring_init(&root.text, 1);
    NodeArray_init(&root.children, 1);
    Node_processChildren(&root, input_file, &all_nodes);

    if (must_sort_nodes) {
        // @Feature { Polish, print nicely, handle date }
        qsort(all_nodes.nodes, all_nodes.len, sizeof(Node), Node_compareDate);
        for (size_t i = 0; i < all_nodes.len; i++) {
            Node_printFmt(all_nodes.nodes[i], 0, i, all_nodes.len);
        }
    }

    if (must_print_tree) for (size_t i = 0; i < root.children.len; i++) {
        Node_printFmt(root.children.nodes[i], 0, i, root.children.len);
    }


    free(all_nodes.nodes);
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


void nodeptrsInBuf(Node **ptrbuf, Node *node, size_t *idx) {
    for (size_t i = 0; i < node->children.len; i++) {
        ptrbuf[*idx] = &node->children.nodes[i];
        nodeptrsInBuf(ptrbuf, &node->children.nodes[i], idx);
        (*idx)++;
    }
}
