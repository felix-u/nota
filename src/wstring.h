#include "base.h"

#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>


#ifndef WSTRING_TYPE
#define WSTRING_TYPE

typedef struct wstring {
    usize len;
    usize cap;
    wchar_t *wstr;
} wstring;

#endif // WSTRING_TYPE


bool iswspaceNotNewline(wchar_t c);

wstring wstring_init(usize init_size);
wstring wstring_initFromCstr(const char *cstr);
wchar_t *wstring_initToWcptr(wstring str);
void wstring_free(wstring wstr);

void wstring_append(wstring *arr, wchar_t c);
void wstring_appendNewlinesFromWstring(wstring *target, wstring *from);
void wstring_appendWstring(wstring *target, wstring *from);
void wstring_nullTerminate(wstring *arr);
void wstring_removeSurroundingWhitespace(wstring *str);

bool wstring_containsNewline(wstring *arr);

void wstring_print(wstring str);
void wstring_println(wstring str);

f64 wstring_toDouble(wstring str);


#ifdef WSTRING_IMPLEMENTATION

bool iswspaceNotNewline(wchar_t c) {
    if (iswspace(c) && c != '\n') return true;
    return false;
}


wstring wstring_init(usize init_size) {
    return (wstring){
        0,
        init_size,
        malloc(init_size * sizeof(wchar_t))
    };
}


wstring wstring_initFromCstr(const char *cstr) {
    const usize cstr_len = strlen(cstr) + 1;
    wstring wstr_return = {
        cstr_len,
        cstr_len,
        malloc(cstr_len * sizeof(wchar_t))
    };
    for (usize i = 0; i < cstr_len; i++) {
        mbtowc(wstr_return.wstr + i, cstr + i, 4);
    }
    return wstr_return;
}


void wstring_free(wstring wstr) {
    if (wstr.wstr != NULL) free(wstr.wstr);
}


void wstring_append(wstring *arr, wchar_t c) {
    if (arr->len == arr->cap) {
        arr->cap *= 2;
        arr->wstr = realloc(arr->wstr, arr->cap * sizeof(wchar_t));
    }
    arr->wstr[arr->len++] = c;
}


void wstring_appendNewlinesFromWstring(wstring *target, wstring *from) {
    for (usize i = 0; i < from->len; i++) {
        if (from->wstr[i] == '\n') wstring_append(target, '\n');
    }
}


void wstring_appendWstring(wstring *target, wstring *from) {
    for (usize i = 0; i < from->len; i++) wstring_append(target, from->wstr[i]);
}


void wstring_nullTerminate(wstring *arr) {
    if (arr->len == arr->cap) {
        arr->cap++;
        arr->wstr = (wchar_t *)realloc(arr->wstr, arr->cap * sizeof(wchar_t));
    }
    arr->wstr[arr->len] = '\0';
}


bool wstring_containsNewline(wstring *arr) {
    for (usize i = 0; i < arr->len; i++) {
        if (arr->wstr[i] == '\n') return true;
    }
    return false;
}


void wstring_print(wstring str) {
    for (usize i = 0; i < str.len; i++) printf("%lc", str.wstr[i]);
}


void wstring_println(wstring str) {
    wstring_print(str);
    putchar('\n');
}


void wstring_removeSurroundingWhitespace(wstring *str) {
    for (usize i = 0; i < str->len; i++) {
        if (!iswspace(str->wstr[i])) {
            if (i > 0) {
                str->len -= i;
                wmemmove(str->wstr, (str->wstr + i), str->len);
            }
            break;
        }
    }

    for (int i = str->len - 1; i >= 0; i--) {
        if (!iswspace(str->wstr[i])) {
            if ((usize)i < str->len) str->len = i + 1;
            return;
        }
    }
}


f64 wstring_toDouble(wstring str) {

    f64 ret = 0;

    char cbuf_int[str.len];
    bool found_decimal = false;
    usize int_idx = 0;
    usize int_cstr_idx = 0;

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
        usize dec_idx = 0;
        for (usize dec_cstr_idx = int_cstr_idx + 1; dec_cstr_idx < str.len; dec_cstr_idx++) {
            char c = (char)str.wstr[dec_cstr_idx];
            if (c >= '0' && c <= '9') {
                cbuf_dec[dec_idx] = (char)str.wstr[dec_cstr_idx];
                dec_idx++;
            }
        }
        f32 dec_add = atof(cbuf_dec);
        for (usize i = 0; i < dec_idx; i++) {
            dec_add /= 10;
        }
        ret += dec_add;
    }

    return ret;
}


wchar_t *wstring_initToWcptr(wstring str) {
    wchar_t *wcptr = malloc(sizeof(wchar_t) * str.len + 1);
    for (usize i = 0; i < str.len; i++) {
        wcptr[i] = str.wstr[i];
    }
    wcptr[str.len] = '\0';
    return wcptr;
}


#endif // WSTRING_IMPLEMENTATION
