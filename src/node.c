#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stddef.h>
#include <wchar.h>
#include <wctype.h>

#include "wstring.h"


typedef struct {
    wchar_t beg;
    wchar_t end;
} DelimiterSet;

const wchar_t NODE_MARKER = '@';
const DelimiterSet DLM_DESC = {'(', ')'};
const DelimiterSet DLM_DATE = {'[', ']'};
const DelimiterSet DLM_TEXT = {'{', '}'};


typedef struct NodeArray {
    size_t len;
    size_t cap;
    struct Node *nodes;
} NodeArray;

typedef struct Node {
    struct Node *parent;
    wstring name;
    wstring desc;
    wstring date;
    wstring text;
    struct NodeArray children;
} Node;

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


Node Node_process(FILE *file, Node *parent) {

    Node this_node;
    this_node.parent = parent;
    wstring_init(&this_node.name, 1);
    wstring_init(&this_node.desc, 1);
    wstring_init(&this_node.date, 1);
    wstring_init(&this_node.text, 1);
    NodeArray_init(&this_node.children, 1);

    bool getting_name = true;
    bool getting_desc = false;
    bool getting_date = false;
    bool getting_text = false;

    wint_t c;
    wchar_t wc;

    wstring text_whitespace_buf;
    wstring_init(&text_whitespace_buf, 1);
    bool text_getting_whitespace = false;

    while ((c = fgetwc(file)) != WEOF) {

        wc = (wchar_t)c;

        if (getting_name) {
            if (wc == DLM_DESC.beg) {
                getting_name = false;
                getting_desc = true;
                continue;
            }
            else if (wc == DLM_DATE.beg) {
                getting_name = false;
                getting_date = true;
                continue;
            }
            else if (wc == DLM_TEXT.beg) {
                getting_name = false;
                getting_text = true;
                continue;
            }
            else wstring_append(&this_node.name, wc);
        }
        else if (getting_desc) {
            if (wc == DLM_DESC.end) {
                getting_desc = false;
            }
            else wstring_append(&this_node.desc, wc);
        }
        else if (getting_date) {
            if (wc == DLM_DATE.end) {
                getting_date = false;
            }
            else wstring_append(&this_node.date, wc);
        }
        else if (getting_text) {
            if (wc == DLM_TEXT.end) {
                getting_text = false;
                break;
            }
            // @Broken{}
            else if (!text_getting_whitespace && whitespaceNotNewline(wc)) text_getting_whitespace = true;
            else if (text_getting_whitespace) {
                if (!whitespaceNotNewline(wc)) text_getting_whitespace = false;
                else if (wc != NODE_MARKER) wstring_append(&text_whitespace_buf, wc);
            }
            else if (wc != NODE_MARKER) wstring_append(&this_node.text, wc);
        }

        if (wc == NODE_MARKER) {
            NodeArray_append(&this_node.children, Node_process(file, &this_node));
        }
        if (!getting_name && !getting_desc && !getting_date && !getting_text) {
            if (wc == DLM_DESC.beg) getting_desc = true;
            else if (wc == DLM_DATE.beg) getting_date = true;
            else if (wc == DLM_TEXT.beg) getting_text = true;
        }

    }

    wstring_removeSurroundingWhitespace(&this_node.text);
    free(text_whitespace_buf.wstr);

    return this_node;
}


void Node_print(Node node) {
    printf("----------- NODE -------\n");
    if (node.name.len > 0) {
        printf("Name: ");
        wstring_println(node.name);
    }
    if (node.desc.len > 0) {
        printf("Desc: ");
        wstring_println(node.desc);
    }
    if (node.date.len > 0) {
        printf("Date: ");
        wstring_println(node.date);
    }
    if (node.text.len > 0) {
        printf("Text: ");
        wstring_println(node.text);
    }
    printf("\n\n");
    for (size_t i = 0; i < node.children.len; i++) {
        printf("~~~ CHILD OF NODE: %ls (%ls) ~~~\n\n", node.name.wstr, node.desc.wstr);
        Node_print(node.children.nodes[i]);
    }
}


void Node_free(Node node) {
    if (node.name.wstr != NULL) free(node.name.wstr);
    if (node.desc.wstr != NULL) free(node.desc.wstr);
    if (node.date.wstr != NULL) free(node.date.wstr);
    if (node.text.wstr != NULL) free(node.text.wstr);
    for (size_t i = 0; i < node.children.len; i++) {
        Node_free(node.children.nodes[i]);
    }
    free(node.children.nodes);
}
