#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>


#ifndef SSTRING_TYPE
#define SSTRING_TYPE

typedef struct sstring {
    size_t len;
    size_t cap;
    uint8_t *sstr;
} sstring;

#endif // SSTRING_TYPE


bool iswspaceNotNewline(uint8_t c);

sstring sstring_init(size_t init_size);
sstring sstring_initFromCstr(const char *cstr);
uint8_t *sstring_initToWcptr(sstring str);
void sstring_free(sstring sstr);

void sstring_append(sstring *arr, uint8_t c);
void sstring_appendNewlinesFromWstring(sstring *target, sstring *from);
void sstring_appendWstring(sstring *target, sstring *from);
void sstring_nullTerminate(sstring *arr);
void sstring_removeSurroundingWhitespace(sstring *str);

bool sstring_containsNewline(sstring *arr);

void sstring_print(sstring str);
void sstring_println(sstring str);

double sstring_toDouble(sstring str);


#ifdef SSTRING_IMPLEMENTATION

bool iswspaceNotNewline(uint8_t c) {
    if (iswspace(c) && c != '\n') return true;
    return false;
}


sstring sstring_init(size_t init_size) {
    return (sstring){
        0,
        init_size,
        (uint8_t *)malloc(init_size * sizeof(uint8_t))
    };
}


sstring sstring_initFromCstr(const char *cstr) {
    const size_t cstr_len = strlen(cstr) + 1;
    sstring sstr_return = {
        cstr_len,
        cstr_len,
        malloc(cstr_len * sizeof(uint8_t))
    };
    for (size_t i = 0; i < cstr_len; i++) {
        mbtowc(sstr_return.sstr + i, cstr + i, 4);
    }
    return sstr_return;
}


void sstring_free(sstring sstr) {
    if (sstr.sstr != NULL) free(sstr.sstr);
}


void sstring_append(sstring *arr, uint8_t c) {
    if (arr->len == arr->cap) {
        arr->cap *= 2;
        arr->sstr = (uint8_t *)realloc(arr->sstr, arr->cap * sizeof(uint8_t));
    }
    arr->sstr[arr->len++] = c;
}


void sstring_appendNewlinesFromWstring(sstring *target, sstring *from) {
    for (size_t i = 0; i < from->len; i++) {
        if (from->sstr[i] == '\n') sstring_append(target, '\n');
    }
}


void sstring_appendWstring(sstring *target, sstring *from) {
    for (size_t i = 0; i < from->len; i++) sstring_append(target, from->sstr[i]);
}


void sstring_nullTerminate(sstring *arr) {
    if (arr->len == arr->cap) {
        arr->cap++;
        arr->sstr = (uint8_t *)realloc(arr->sstr, arr->cap * sizeof(uint8_t));
    }
    arr->sstr[arr->len] = '\0';
}


bool sstring_containsNewline(sstring *arr) {
    for (size_t i = 0; i < arr->len; i++) {
        if (arr->sstr[i] == '\n') return true;
    }
    return false;
}


void sstring_print(sstring str) {
    for (size_t i = 0; i < str.len; i++) printf("%lc", str.sstr[i]);
}


void sstring_println(sstring str) {
    sstring_print(str);
    putchar('\n');
}


void sstring_removeSurroundingWhitespace(sstring *str) {
    for (size_t i = 0; i < str->len; i++) {
        if (!iswspace(str->sstr[i])) {
            if (i > 0) {
                str->len -= i;
                wmemmove(str->sstr, (str->sstr + i), str->len);
            }
            break;
        }
    }

    for (int i = str->len - 1; i >= 0; i--) {
        if (!iswspace(str->sstr[i])) {
            if ((size_t)i < str->len) str->len = i + 1;
            return;
        }
    }
}


double sstring_toDouble(sstring str) {

    double ret = 0;

    char cbuf_int[str.len];
    bool found_decimal = false;
    size_t int_idx = 0;
    size_t int_cstr_idx = 0;

    for (; int_cstr_idx < str.len; int_cstr_idx++) {
        char c = (char)str.sstr[int_cstr_idx];
        if (c >= '0' && c <= '9') {
            cbuf_int[int_idx] = (char)str.sstr[int_cstr_idx];
            int_idx++;
        }
        else if (c == '.' || c == ',' || c == ' ') {
            found_decimal = true;
            break;
        }
    }
    ret += atof(cbuf_int);

    if (found_decimal) {
        char cbuf_dec[str.len - int_cstr_idx];
        size_t dec_idx = 0;
        for (size_t dec_cstr_idx = int_cstr_idx + 1; dec_cstr_idx < str.len; dec_cstr_idx++) {
            char c = (char)str.sstr[dec_cstr_idx];
            if (c >= '0' && c <= '9') {
                cbuf_dec[dec_idx] = (char)str.sstr[dec_cstr_idx];
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


uint8_t *sstring_initToCptr(sstring str) {
    uint8_t *wcptr = malloc(sizeof(uint8_t) * str.len + 1);
    for (size_t i = 0; i < str.len; i++) {
        wcptr[i] = str.sstr[i];
    }
    wcptr[str.len] = '\0';
    return wcptr;
}


#endif // SSTRING_IMPLEMENTATION
