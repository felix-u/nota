#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
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
bool wstring_containsNewline(wstring *arr);
void wstring_print(wstring str);
void wstring_println(wstring str);
void wstring_removeSurroundingWhitespace(wstring *str);
unsigned int wstring_toUint(wstring str);


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

    for (int i = str->len; i >= 0; i--) {
        if (!whitespace(str->wstr[i])) {
            if ((size_t)i < str->len) str->len = i + 1;
            return;
        }
    }

}


unsigned int wstring_toUint(wstring str) {
    unsigned int num = 0;
    size_t magnitude = 0;

    for (int i = str.len; i >= 0; i--) {
        if (str.wstr[i] >= '0' && str.wstr[i] <= '9') {
            unsigned int digit = str.wstr[i] - 48;
            for (size_t j = 0; j < magnitude; j++) digit *= 10;
            num += digit;
            magnitude++;
        }
    }

    return num;
}

#endif // WSTRING_IMPLEMENTATION
