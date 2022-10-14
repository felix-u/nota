#include <stdlib.h>
#include <stddef.h>
#include <wchar.h>

#ifndef WSTRING_STRUCT_IMPLEMENTATION
    #define WSTRING_STRUCT_IMPLEMENTATION
    typedef struct wstring {
        size_t len;
        size_t cap;
        wchar_t *wstr;
    } wstring;
#endif

void wstring_init(wstring *arr, size_t init_size);
void wstring_append(wstring *arr, wchar_t c);
void wstring_print(wstring str);
void wstring_println(wstring str);
void wstring_removeSurroundingWhitespace(wstring *str);

#ifndef WSTRING_IMPLEMENTATION
    #define WSTRING_IMPLEMENTATION
#endif

#ifdef WSTRING_IMPLEMENTATION

void wstring_init(wstring *arr, size_t init_size) {
    arr->wstr = malloc(init_size * sizeof(wchar_t));
    arr->len = 0;
    arr->cap = init_size;
}

void wstring_append(wstring *arr, wchar_t c) {
    if (arr->len == arr->cap) {
        arr->cap *= 2;
        arr->wstr = realloc(arr->wstr, arr->cap * sizeof(wchar_t));
    }
    arr->wstr[arr->len++] = c;
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
        if (!charIsWhiteSpace(str->wstr[i])) {
            if (i > 0) {
                str->len -= i;
                wmemmove(str->wstr, (str->wstr + i), str->len);
            }
            break;
        }
    }

    for (int i = str->len; i >= 0; i--) {
        if (!charIsWhiteSpace(str->wstr[i])) {
            if ((size_t)i < str->len) {
                str->len = i + 1;
            }
            else if ((size_t)i == str->len) str->len = 0;
            return;
        }
    }
}

#endif
