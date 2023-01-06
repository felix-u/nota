#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stddef.h>
#include <unistd.h>
#include <wchar.h>
#include <wctype.h>

#define ANSI_IMPLEMENTATION
#include "ansi.h"

#include "arena.h"

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
    double date_num;
    wstring text;
    bool hidden;
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


void NodeArray_toBuf(NodeArray *arr, Node *buf, size_t *idx) {
    for (size_t i = 0; i < arr->len; i++) {
        buf[*idx] = arr->nodes[i];
        (*idx)++;
        NodeArray_toBuf(&arr->nodes[i].children, buf, idx);
    }
}


Node Node_process(FILE *file, Node *parent, size_t *nodes_num) {

    Node this_node;
    this_node.parent = parent;
    wstring_init(&this_node.name, 1);
    wstring_init(&this_node.desc, 1);
    wstring_init(&this_node.date, 1);
    this_node.date_num = 0;
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
    bool found_text_not_whitespace = false;

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

            if (!text_getting_whitespace) {
                if (whitespace(wc)) {
                    text_getting_whitespace = true;
                    text_whitespace_buf.len = 0;
                }
                else if (wc != NODE_MARKER) {
                    wstring_append(&this_node.text, wc);
                    found_text_not_whitespace = true;
                }
            }
            if (text_getting_whitespace) {
                if (whitespace(wc)) wstring_append(&text_whitespace_buf, wc);
                else {
                    text_getting_whitespace = false;

                    if (wstring_containsNewline(&text_whitespace_buf)) {
                        wstring_appendNewlinesFromWstring(&this_node.text, &text_whitespace_buf);
                    }
                    else wstring_appendWstring(&this_node.text, &text_whitespace_buf);

                    if (wc != NODE_MARKER) wstring_append(&this_node.text, wc);
                }
            }

        }

        if (wc == NODE_MARKER) {
            NodeArray_append(&this_node.children, Node_process(file, &this_node, nodes_num));
            (*nodes_num)++;
        }
        if (!getting_name && !getting_desc && !getting_date && !getting_text) {
            if (wc == DLM_DESC.beg) getting_desc = true;
            else if (wc == DLM_DATE.beg) getting_date = true;
            else if (wc == DLM_TEXT.beg) getting_text = true;
        }

    }

    wstring_removeSurroundingWhitespace(&this_node.name);

    wstring_removeSurroundingWhitespace(&this_node.desc);

    wstring_removeSurroundingWhitespace(&this_node.date);
    this_node.date_num = wstring_toDouble(this_node.date);

    wstring_removeSurroundingWhitespace(&this_node.text);
    // If the text consists only of whitespace, treat it as empty.
    if (!found_text_not_whitespace) this_node.text.len = 0;
    free(text_whitespace_buf.wstr);

    this_node.hidden = false;

    return this_node;
}


void Node_processChildren(Node *node, FILE *file, size_t *nodes_num) {
    wint_t c;
    wchar_t wc;
    while ((c = fgetwc(file)) != WEOF) {
        wc = (wchar_t)c;
        if (wc == NODE_MARKER) {
            NodeArray_append(&node->children, Node_process(file, node, nodes_num));
            (*nodes_num)++;
        }
    }
}


void Node_printDebug(Node node, size_t indent_level, size_t num_current, size_t num_max) {
    if (node.name.len > 0) {
        for (size_t i = 0; i < indent_level; i++) putchar('\t');
        printf("Name: ");
        wstring_println(node.name);
    }

    if (node.desc.len > 0) {
        for (size_t i = 0; i < indent_level; i++) putchar('\t');
        printf("Desc: ");
        wstring_println(node.desc);
    }

    for (size_t i = 0; i < indent_level; i++) putchar('\t');
    printf("Date:");
    if (node.date.len > 0) {
        putchar(' ');
        wstring_print(node.date);
    }
    printf(" (%0.6f)\n", node.date_num);

    if (node.text.len > 0) {
        for (size_t i = 0; i < indent_level; i++) putchar('\t');
        printf("Text: ");
        for (size_t i = 0; i < node.text.len; i++) {
            printf("%lc", node.text.wstr[i]);
            if (node.text.wstr[i] == '\n') {
                for (size_t j = 0; j < indent_level; j++) putchar('\t');
            }
        }
        putchar('\n');
    }

    for (size_t i = 0; i < node.children.len; i++) {
        Node_printDebug(node.children.nodes[i], indent_level + 1, i, node.children.len);
    }

    // Don't print excessive newlines if end reached
    if (num_current != num_max - 1) printf("\n");
}


void Node_printFmt(Node node, size_t indent_level, size_t num_current, size_t num_max) {

    if (node.hidden) return;

    if (node.name.len > 0) {
        for (size_t i = 0; i < indent_level; i++) putchar('\t');
        ansi_set("%s", ANSI_FMT_BOLD);
        wstring_print(node.name);
        ansi_reset();
    }
    else {
        ansi_set("%s", ANSI_BG_BLACK);
        printf("Anonymous");
        ansi_reset();
    }

    if (node.desc.len > 0) {
        printf(" | ");
        ansi_set("%s", ANSI_FG_BLUE);
        wstring_print(node.desc);
        ansi_reset();
    }

    if (node.date.len > 0) {
        printf(" | ");
        ansi_set("%s", ANSI_FG_GREEN);
        wstring_print(node.date);
        ansi_reset();
    }

    putchar('\n');

    if (node.text.len > 0) {
        for (size_t i = 0; i < indent_level; i++) putchar('\t');
        for (size_t i = 0; i < node.text.len; i++) {
            printf("%lc", node.text.wstr[i]);
            if (node.text.wstr[i] == '\n') {
                for (size_t j = 0; j < indent_level; j++) putchar('\t');
            }
        }
        putchar('\n');
    }

    for (size_t i = 0; i < node.children.len; i++) {
        Node_printFmt(node.children.nodes[i], indent_level + 1, i, node.children.len);
    }

    // Don't print newline if end reached
    if (num_current != num_max - 1) printf("\n");
}


int Node_compareDateAscending(const void *a, const void *b) {
    return ((Node *)a)->date_num - ((Node *)b)->date_num;
}


int Node_compareDateDescending(const void *a, const void *b) {
    return ((Node *)b)->date_num - ((Node *)a)->date_num;
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
