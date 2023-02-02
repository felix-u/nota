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
#define ARGS_BINARY_VERSION "0.3-dev"
#include "args.h"
#include "int_types.h"
#define NODE_IMPLEMENTATION
#include "node.h"
#define TOKEN_IMPLEMENTATION
#include "token.h"
#define WSTRING_IMPLEMENTATION
#include "wstring.h"

#define ANSI_IMPLEMENTATION
#include "ansi.h"


#define EX_USAGE 64
#define EX_IOERR 74

typedef const enum Token {
    // Single-character syntax
    T_PAREN_LEFT, T_PAREN_RIGHT, T_SQUARE_BRACKET_LEFT, T_SQUARE_BRACKET_RIGHT,
    T_CURLY_BRACKET_LEFT, T_CURLY_BRACKET_RIGHT, T_COLON, T_SEMICOLON, T_AT,
    // Types
    T_STR, T_NUM,
    // Directives
    T_MODS, T_PROVIDES, T_INHERITS,
    T_EOF,
    T_COUNT
} Token;

#define IGNORE_IN_CHARS "\"'`"


double cstrToDouble(char *cstr);
double currentTimeToDouble(void);


usize fsize(FILE *fp);


int main(int argc, char **argv) {

    setlocale(LC_ALL, "");
    if (getenv("NOTA_NO_COLOR") == NULL && getenv("NOTA_NO_COLOUR") == NULL) ansi_stateSet();

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
    args_Flag forcecolour_flag = {
        false, "force-colour",
        "forces colour in output. This will override TERM=dumb, \n"
        "NO_COLO(U)R, and NOTA_NO_COLO(U)R",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };
    args_Flag forcecolor_flag = {
        false, "force-color",
        "equivalent to the above",
        ARGS_OPTIONAL,
        false, NULL, 0,
        ARGS_BOOLEAN, ARGS_EXPECTS_NONE
    };

    args_Flag *flags[] = {
        &nocolour_flag,
        &nocolor_flag,
        &forcecolour_flag,
        &forcecolor_flag,
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
    else if (forcecolour_flag.is_present || forcecolor_flag.is_present) ansi_enabled = true;

    FILE *input_file = fopen(positional_args[0], "r");
    if (input_file == NULL) {
        printf("%s: no such file or directory '%s'\n", ARGS_BINARY_NAME, positional_args[0]);
        return EX_IOERR;
    }


    /* @Note { Closing and opening the file again is stupid, but it seems to be the only way I can get the seek
               position to actually reset. }; */

    usize filesize = fsize(input_file);
    wchar_t filebuf[filesize];
    fclose(input_file);
    input_file = fopen(positional_args[0], "r");
    if (input_file == NULL) {
        printf("%s: no such file or directory '%s'\n", ARGS_BINARY_NAME, positional_args[0]);
        return EX_IOERR;
    }

    wint_t c;
    wchar_t wc;
    usize i = 0;
    for (; (c = fgetwc(input_file)) != WEOF; i++) {
        wc = (wchar_t)c;
        filebuf[i] = wc;
    }
    filebuf[i++] = '\0';
    fclose(input_file);

    // filebuf[] now contains the input file.

    token_SOA tokens[filesize];
    // token_process(tokens, );

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


usize fsize(FILE *fp) {
    usize start = ftell(fp);
    fseek(fp, 0L, SEEK_END);
    usize filesize = ftell(fp);
    fseek(fp, start, SEEK_SET);
    return filesize;
}
