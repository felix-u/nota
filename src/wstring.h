#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>


#ifndef WSTRING_TYPE
#define WSTRING_TYPE

typedef struct wstring {
    size_t len;
    size_t cap;
    wchar_t *wstr;
} wstring;

#endif // WSTRING_TYPE


bool whitespaceNotNewline(wchar_t c);
bool whitespace(wchar_t c);

void wstring_init(wstring *arr, size_t init_size);
void wstring_append(wstring *arr, wchar_t c);
void wstring_appendNewlinesFromWstring(wstring *target, wstring *from);
void wstring_appendWstring(wstring *target, wstring *from);
void wstring_removeSurroundingWhitespace(wstring *str);

bool wstring_containsNewline(wstring *arr);

void wstring_print(wstring str);
void wstring_println(wstring str);

double wstring_toDouble(wstring str);


#ifdef WSTRING_IMPLEMENTATION

bool whitespaceNotNewline(wchar_t c) {
    if (c == ' ' || c == '\t') return true;
    return false;
}


bool whitespace(wchar_t c) {
    if (whitespaceNotNewline(c) || c == '\n') return true;
    return false;
}


void wstring_init(wstring *arr, size_t init_size) {
    arr->wstr = (wchar_t *)malloc(init_size * sizeof(wchar_t));
    arr->len = 0;
    arr->cap = init_size;
}


void wstring_append(wstring *arr, wchar_t c) {
    if (arr->len == arr->cap) {
        arr->cap *= 2;
        arr->wstr = (wchar_t *)realloc(arr->wstr, arr->cap * sizeof(wchar_t));
    }
    arr->wstr[arr->len++] = c;
}


void wstring_appendNewlinesFromWstring(wstring *target, wstring *from) {
    for (size_t i = 0; i < from->len; i++) {
        if (from->wstr[i] == '\n') wstring_append(target, '\n');
    }
}


void wstring_appendWstring(wstring *target, wstring *from) {
    for (size_t i = 0; i < from->len; i++) wstring_append(target, from->wstr[i]);
}


bool wstring_containsNewline(wstring *arr) {
    for (size_t i = 0; i < arr->len; i++) {
        if (arr->wstr[i] == '\n') return true;
    }
    return false;
}


void wstring_print(wstring str) {
    for (size_t i = 0; i < str.len; i++) printf("%lc", str.wstr[i]);
}


void wstring_println(wstring str) {
    wstring_print(str);
    putchar('\n');
}


void wstring_removeSurroundingWhitespace(wstring *str) {
    for (size_t i = 0; i < str->len; i++) {
        if (!whitespace(str->wstr[i])) {
            if (i > 0) {
                str->len -= i;
                wmemmove(str->wstr, (str->wstr + i), str->len);
            }
            break;
        }
    }

    for (int i = str->len - 1; i >= 0; i--) {
        if (!whitespace(str->wstr[i])) {
            if ((size_t)i < str->len) str->len = i + 1;
            return;
        }
    }
}


double wstring_toDouble(wstring str) {

    double ret = 0;

    char cbuf_int[str.len];
    bool found_decimal = false;
    size_t int_idx = 0;
    size_t int_cstr_idx = 0;

    for (; int_cstr_idx < str.len; int_cstr_idx++) {
        char c = (char)str.wstr[int_cstr_idx];
        if (c >= '0' && c <= '9') {
            cbuf_int[int_idx] = (char)str.wstr[int_cstr_idx];
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
            char c = (char)str.wstr[dec_cstr_idx];
            if (c >= '0' && c <= '9') {
                cbuf_dec[dec_idx] = (char)str.wstr[dec_cstr_idx];
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


#endif // WSTRING_IMPLEMENTATION
