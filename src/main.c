#include <locale.h>
#include <math.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <strings.h>
#include <time.h>
#include <wchar.h>
#include <wctype.h>

#define ARGS_IMPLEMENTATION
#define ARGS_BINARY_NAME "nota"
#define ARGS_BINARY_VERSION "0.2-dev"
#include "args.h"
#include "int_types.h"
#include "node.c"
#define WSTRING_IMPLEMENTATION
#include "wstring.h"
#define ARENA_IMPLEMENTATION
#include "arena.h"

#define EX_USAGE 64
#define EX_IOERR 74


typedef enum SortOption {
    SORT_NONE,
    SORT_ASCENDING,
    SORT_DESCENDING,
} SortOption;

typedef enum Cutoff {
    CUT_AFTER,
    CUT_BEFORE,
    CUT_NONE,
} Cutoff;


double cstrToDouble(char *cstr);
double currentTimeToDouble(void);


SortOption sort_mode = SORT_NONE;
double user_date = 0;
Cutoff cutoff_mode = CUT_NONE;


int main(int argc, char **argv) {

    setlocale(LC_ALL, "");
    if (getenv("NOTA_NO_COLOR") == NULL && getenv("NOTA_NO_COLOUR") == NULL) ansi_stateSet();

    args_Flag after_flag = {
        'a', "after",
        "narrows selection to nodes after given date(s), or after 'now' if none \n"
        "are specified",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };
    args_Flag before_flag = {
        'b', "before",
        "narrows selection to nodes before given date(s), or before 'now' if none \n"
        "are specified",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };
    args_Flag date_flag = {
        'd', "date",
        "narrows selection by given date: <ISO 8601>, <NUM>, 'now'/'n'.\n"
        "Flags that rely on a date use 'now' if the user does not specify one",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_SINGLE_OPT, ARGS_EXPECTS_STRING
    };
    args_Flag desc_flag = {
        false, "desc",
        "narrows selection by given description",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_SINGLE_OPT, ARGS_EXPECTS_STRING
    };
    args_Flag node_flag = {
        'n', "node",
        "narrows selection by given node name(s)",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_SINGLE_OPT, ARGS_EXPECTS_STRING
    };
    args_Flag tagchar_flag = {
        false, "tagchar",
        "provides tag character",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_SINGLE_OPT, ARGS_EXPECTS_STRING
    };
    args_Flag tagged_flag = {
        't', "tagged",
        "limits selection to tagged nodes (default tag character: 'x')",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };
    args_Flag not_tagged_flag = {
        false, "not-tagged",
        "limits selection to nodes NOT tagged (default tag character: 'x')",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };
    args_Flag sort_flag = {
        's', "sort",
        "sorts by: 'descending'/'d', 'ascending'/'a'",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_SINGLE_OPT, ARGS_EXPECTS_STRING
    };
    args_Flag upcoming_flag = {
        'u', "upcoming",
        "equivalent to '--after --sort ascending'",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };
    args_Flag nocolour_flag = {
        false, "no-colour",
        "disables colour in output. This will also occur if TERM=dumb, \n"
        "NO_COLO(U)R or NOTA_NO_COLO(U)R is set, or the output is piped to a file",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };
    args_Flag nocolor_flag = {
        false, "no-color",
        "equivalent to the above",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };

    args_Flag *flags[] = {
        &after_flag,
        &before_flag,
        &date_flag,
        &desc_flag,
        &node_flag,
        &tagchar_flag,
        &tagged_flag,
        &not_tagged_flag,
        &sort_flag,
        &upcoming_flag,
        &nocolour_flag,
        &nocolor_flag,
        &ARGS_HELP_FLAG,
        &ARGS_VERSION_FLAG,
    };

    const usize flags_count = sizeof(flags) / sizeof(flags[0]);
    usize positional_num = 0;
    const usize positional_cap = 256;
    char *positional_args[positional_cap];
    int args_return = args_process(argc, argv, "parser for simple node notation", flags_count, flags,
                                   &positional_num, positional_args, ARGS_EXPECTS_FILE, ARGS_POSITIONAL_SINGLE,
                                   positional_cap);
    if (args_return != ARGS_RETURN_CONTINUE) return args_return;

    if (nocolour_flag.is_present || nocolor_flag.is_present) ansi_enabled = false;

    if (upcoming_flag.is_present) {
        cutoff_mode = CUT_AFTER;
        sort_mode = SORT_ASCENDING;
    }

    if (date_flag.is_present) {
        if (!strncasecmp(date_flag.opts[0], "n", 1) || !strncasecmp(date_flag.opts[0], "now", 3)) {
            user_date = currentTimeToDouble();
        }
        else {
            user_date = cstrToDouble(date_flag.opts[0]);
            if (user_date == 0) {
                printf("%s: provide valid date in ISO format or as number\n", ARGS_BINARY_NAME);
                args_helpHint();
                return EX_USAGE;
            }
        }
    }

    if (sort_flag.is_present) {
        if (user_date == 0) user_date = currentTimeToDouble();

        if (!strncasecmp(sort_flag.opts[0], "a", 1) || !strncasecmp(sort_flag.opts[0], "ascending", 9)) {
            sort_mode = SORT_ASCENDING;
        }
        else if (!strncasecmp(sort_flag.opts[0], "d", 1) || !strncasecmp(sort_flag.opts[0], "descending", 9)) {
            sort_mode = SORT_DESCENDING;
        }
        else {
            printf("%s: '%s' is not a valid sorting option\n", ARGS_BINARY_NAME, sort_flag.opts[0]);
            args_helpHint();
            return EX_USAGE;
        }
    }

    if (tagchar_flag.is_present) {
        TAG = tagchar_flag.opts[0][0];
        mbtowc(&TAG, tagchar_flag.opts[0], 4);
    }

    if (after_flag.is_present) cutoff_mode = CUT_AFTER;
    else if (before_flag.is_present) cutoff_mode = CUT_BEFORE;

    if (cutoff_mode != CUT_NONE && user_date == 0) user_date = currentTimeToDouble();

    FILE *input_file = fopen(positional_args[0], "r");
    if (input_file == NULL) {
        printf("%s: no such file or directory '%s'\n", ARGS_BINARY_NAME, positional_args[0]);
        return EX_IOERR;
    }

    usize nodes_num = 0;

    Node root = {
        NULL,             // parent
        wstring_init(1),  // name
        wstring_init(1),  // desc
        wstring_init(1),  // date
        -1,               // date_num
        false,            // tag
        wstring_init(1),  // text
        false,            // hidden
        NodeArray_give(1) // children
    };

    Node_processChildren(&root, input_file, &nodes_num);

    Node node_buf[nodes_num];
    usize idx = 0;
    NodeArray_toBuf(&root.children, node_buf, &idx);

    isize selection_len = nodes_num;

    // Sorting
    if (sort_mode == SORT_ASCENDING) qsort(node_buf, nodes_num, sizeof(Node), Node_compareDateAscending);
    else if (sort_mode == SORT_DESCENDING) qsort(node_buf, nodes_num, sizeof(Node), Node_compareDateDescending);

    // Limit by date
    if (cutoff_mode != CUT_NONE) {
        for (usize i = 0; i < nodes_num; i++) {
            if (!node_buf[i].hidden && node_buf[i].date_num == 0) {
                node_buf[i].hidden = true;
                selection_len--;
            }
        }
    }

    if (cutoff_mode == CUT_AFTER) {
        for (usize i = 0; i < nodes_num; i++) {
            if (!node_buf[i].hidden && node_buf[i].date_num < user_date) {
                node_buf[i].hidden = true;
                selection_len--;
            }
        }
    }
    else if (cutoff_mode == CUT_BEFORE) {
        for (usize i = 0; i < nodes_num; i++) {
            if (!node_buf[i].hidden && node_buf[i].date_num > user_date) {
                node_buf[i].hidden = true;
                selection_len--;
            }
        }
    }

    // Limit by description
    if (desc_flag.is_present) {
        char *user_desc = desc_flag.opts[0];
        usize user_desc_len = strlen(user_desc);
        wstring w_user_desc = {
            user_desc_len,
            user_desc_len,
            malloc(user_desc_len * sizeof(wchar_t))
        };
        for (usize i = 0; i < user_desc_len; i++) {
            mbtowc(w_user_desc.wstr + i, user_desc + i, 4);
        }
        for (usize i = 0; i < nodes_num; i++) if (!node_buf[i].hidden) {
            for (usize j = 0; j < w_user_desc.len; j++) {
                if (w_user_desc.wstr[j] != node_buf[i].desc.wstr[j]) {
                    node_buf[i].hidden = true;
                    selection_len--;
                    break;
                }
            }
        }
        free(w_user_desc.wstr);
    }

    // If date is the only flag used, only provide nodes on that date.
    if (user_date != 0 && sort_mode == SORT_NONE && cutoff_mode == CUT_NONE) {
        for (usize i = 0; i < nodes_num; i++) {
            if (!node_buf[i].hidden &&
                (node_buf[i].date_num < floor(user_date) || node_buf[i].date_num > ceil(user_date)))
            {
                node_buf[i].hidden = true;
                selection_len--;
            }
        }
    }

    // Limit by tag
    if (tagged_flag.is_present) {
        for (usize i = 0; i < nodes_num; i++) {
            if (!node_buf[i].hidden && !node_buf[i].tag) {
                node_buf[i].hidden = true;
                selection_len--;
            }
        }
    }
    else if (not_tagged_flag.is_present) {
        for (usize i = 0; i < nodes_num; i++) {
            if (!node_buf[i].hidden && node_buf[i].tag) {
                node_buf[i].hidden = true;
                selection_len--;
            }
        }
    }

    // Limit by node name
    if (node_flag.is_present) {
        char *user_name = node_flag.opts[0];
        usize user_name_len = strlen(user_name);
        wstring w_user_name = {
            user_name_len,
            user_name_len,
            malloc(user_name_len * sizeof(wchar_t))
        };
        for (usize i = 0; i < user_name_len; i++) {
            mbtowc(w_user_name.wstr + i, user_name + i, user_name_len);
        }
        for (usize i = 0; i < nodes_num; i++) {
            if (node_buf[i].hidden) continue;
            for (usize j = 0; j < w_user_name.len; j++) {
                if (w_user_name.wstr[j] != node_buf[i].name.wstr[j]) {
                    node_buf[i].hidden = true;
                    selection_len--;
                    break;
                }
            }
        }
        free(w_user_name.wstr);
    }

    // Print from node_buf if flags used, else print from root.children.nodes.
    if (args_optionalFlagsPresent(flags_count, flags)) {
        for (usize i = 0; i < nodes_num; i++) {
            Node_printFmt(node_buf[i], 0, i, nodes_num);
        }
    }
    else {
        for (usize i = 0; i < root.children.len; i++) {
            Node_printFmt(root.children.nodes[i], 0, i, root.children.len);
        }
    }


    if (selection_len <= 0) printf("%s: no nodes matched your selection\n", ARGS_BINARY_NAME);

    Node_free(root);
    fclose(input_file);

    return EXIT_SUCCESS;
}


double cstrToDouble(char *cstr) {
    double ret = 0;

    usize str_len = strlen(cstr);
    char cbuf_int[str_len];
    bool found_decimal = false;
    usize int_idx = 0;
    usize int_cstr_idx = 0;

    for (; int_cstr_idx < str_len; int_cstr_idx++) {
        char c = cstr[int_cstr_idx];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) return 0;
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
        usize dec_idx = 0;
        for (usize dec_cstr_idx = int_cstr_idx + 1; dec_cstr_idx < str_len; dec_cstr_idx++) {
            char c = cstr[dec_cstr_idx];
            if (c >= '0' && c <= '9') {
                cbuf_dec[dec_idx] = cstr[dec_cstr_idx];
                dec_idx++;
            }
        }
        float dec_add = atof(cbuf_dec);
        for (usize i = 0; i < dec_idx; i++) {
            dec_add /= 10;
        }
        ret += dec_add;
    }

    return ret;
}


double currentTimeToDouble(void) {
    time_t t = time(NULL);
    struct tm date = *localtime(&t);
    date.tm_year += 1900;
    date.tm_mon += 1;
    // 33 is the max possible length of the formatted string below, courtesy of the compiler
    const usize date_cstr_size_cap = 33;
    char date_cstr[date_cstr_size_cap];

    snprintf(date_cstr, date_cstr_size_cap, "%04d%02d%02d.%02d%02d\n",
            (i16)date.tm_year,
            (i16)date.tm_mon,
            (i16)date.tm_mday,
            (i16)date.tm_hour,
            (i16)date.tm_min);
    return atof(date_cstr);
}
