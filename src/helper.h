#include <stdio.h>
#include <stdint.h>


double cstrToDouble(char *cstr);
double currentTimeToDouble(void);
size_t fsize(FILE *fp);


#ifdef HELPER_IMPLEMENTATION

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

double cstrToDouble(char *cstr) {
    double ret = 0;

    size_t str_len = strlen(cstr);
    char cbuf_int[str_len];
    bool found_decimal = false;
    size_t int_idx = 0;
    size_t int_cstr_idx = 0;

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


double currentTimeToDouble(void) {
    time_t t = time(NULL);
    struct tm date = *localtime(&t);
    date.tm_year += 1900;
    date.tm_mon += 1;
    // 33 is the max possible length of the formatted string below, courtesy of the compiler
    const size_t date_cstr_size_cap = 33;
    char date_cstr[date_cstr_size_cap];

    snprintf(date_cstr, date_cstr_size_cap, "%04d%02d%02d.%02d%02d\n",
            (int16_t)date.tm_year,
            (int16_t)date.tm_mon,
            (int16_t)date.tm_mday,
            (int16_t)date.tm_hour,
            (int16_t)date.tm_min);
    return atof(date_cstr);
}


size_t fsize(FILE *fp) {
    size_t start = ftell(fp);
    fseek(fp, 0L, SEEK_END);
    size_t filesize = ftell(fp);
    fseek(fp, start, SEEK_SET);
    return filesize;
}
#endif // HELPER_H
