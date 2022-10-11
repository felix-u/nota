#include <stdlib.h>
#include <stdio.h>
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
    // arr->nodes = malloc(init_size * sizeof(Node));
    arr->nodes = calloc(init_size, sizeof(Node));
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


Node Node_process(FILE *file, Node *parent) {

    Node this_node;
    this_node.parent = parent;
    wstring_init(&this_node.name, 1);
    wstring_init(&this_node.desc, 1);
    wstring_init(&this_node.date, 1);
    wstring_init(&this_node.text, 1);
    NodeArray_init(this_node.children, 1);

    bool getting_name = true;
    bool getting_desc = false;
    bool getting_date = false;
    bool getting_text = false;

    wint_t c;
    wchar_t wc;
    while ((c = fgetwc(file)) != WEOF) {

        wc = (wchar_t)c;

        if (getting_name == true) {
            if (wc == DLM_DESC.beg) {
                getting_name = false;
                getting_desc = true;
            }
            else if (wc == DLM_DATE.beg) {
                getting_name = false;
                getting_date = true;
            }
            else if (wc == DLM_TEXT.beg) {
                getting_name = false;
                getting_text = true;
            }
            else wstring_append(&this_node.name, c);
        }
        else if (getting_desc == true) {
            if (wc == DLM_DESC.end) getting_desc = false;
            else wstring_append(&this_node.desc, c);
        }
        else if (getting_date == true) {
            if (wc == DLM_DATE.end) getting_date = false;
            else wstring_append(&this_node.date, c);
        }
        else if (getting_text == true) {
            if (wc == DLM_TEXT.end) {
                getting_text = false;
                break;
            }
            else wstring_append(&this_node.text, c);
        }

        // if (wc == NODE_MARKER) {
        //     NodeArray_append(this_node.children, Node_process(file, &this_node));
        // }
        if (wc == DLM_DESC.beg) getting_desc = true;
        else if (wc == DLM_DATE.beg) getting_date = true;
        else if (wc == DLM_TEXT.beg) getting_text = true;
    }

    return this_node;
}
