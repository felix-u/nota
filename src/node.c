#include <stdlib.h>
#include <stdbool.h>
#include <stddef.h>
#include <wchar.h>
#include <wctype.h>

typedef struct {
    wchar_t beg;
    wchar_t end;
} DelimiterSet;

const wchar_t NODE_MARKER = '@';
const DelimiterSet DLM_DESC = {'(', ')'};
const DelimiterSet DLM_DATE = {'[', ']'};
const DelimiterSet DLM_TEXT = {'{', '}'};

bool charIsWhiteSpace(wchar_t c) {
    if (c == ' ' || c == '\t' || c == '\n') return true;
    return false;
}

// https://stackoverflow.com/questions/3536153/c-dynamically-growing-array


typedef struct {
    size_t len;
    size_t cap;
    wchar_t *wstr;
} wstring;

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


typedef struct Node {
    struct Node *parent;
    wstring name;
    wstring desc;
    wstring date;
    wstring text;
    struct NodeArray *children;
} Node;


typedef struct NodeArray {
    size_t len;
    size_t cap;
    struct Node *nodes;
} NodeArray;

void NodeArray_init(NodeArray *arr, size_t init_size) {
    arr->nodes = malloc(init_size * sizeof(Node));
    arr->len = 0;
    arr->cap = init_size;
}

void NodeArray_append(NodeArray *arr, Node node) {
    if (arr->len == arr->cap) {
        arr->cap *= 2;
        arr->nodes = realloc(arr->nodes, arr->cap * sizeof(Node));
    }
    arr->nodes[arr->len++] = node;
}
