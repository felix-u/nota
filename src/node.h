#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stddef.h>
#include <unistd.h>
#include <wchar.h>
#include <wctype.h>

#include "ansi.h"
#include "wstring.h"

#ifndef node_TYPE
#define node_TYPE

typedef struct {
    wchar_t beg;
    wchar_t end;
} node_DelimiterSet;

const wchar_t NODE_MARKER = '@';
      wchar_t TAG         = 'x';

const node_DelimiterSet DLM_DESC = { '(', ')' };
const node_DelimiterSet DLM_DATE = { '[', ']' };
const node_DelimiterSet DLM_TAG  = { '<', '>' };
const node_DelimiterSet DLM_TEXT = { '{', '}' };


typedef struct node_Array {
    size_t len;
    size_t cap;
    struct node *nodes;
} node_Array;

typedef struct node {
    struct node *parent;
    wstring name;
    wstring desc;
    wstring date;
    double date_num;
    bool tag;
    wstring text;
    bool hidden;
    struct node_Array children;
    char *filename;
    size_t line_num;
} node;

#endif // node_TYPE


node_Array node_Array_init(size_t init_size);
void node_Array_append(node_Array *arr, node node);
void node_Array_toBuf(node_Array *arr, node *buf, size_t *idx);

node node_process(FILE *file, node *parent, char *filename, size_t *line_num, size_t *nodes_num);
void node_processChildren(node *node, FILE *file, char *filename, size_t *line_num, size_t *nodes_num);
void node_printFmt(node node, size_t indent_level, size_t num_current, size_t num_max);
int node_compareDateAscending(const void *a, const void *b);
int node_compareDateDescending(const void *a, const void *b);
void node_free(node node);


#ifdef NODE_IMPLEMENTATION

node_Array node_Array_init(size_t init_size) {
    return (node_Array){
        0,
        init_size,
        malloc(init_size * sizeof(node))
    };
}

void node_Array_append(node_Array *arr, node n) {
    if (arr->len == arr->cap) {
        arr->cap *= 2;
        arr->nodes = realloc(arr->nodes, arr->cap * sizeof(node));
    }
    arr->nodes[arr->len++] = n;
}


void node_Array_toBuf(node_Array *arr, node *buf, size_t *idx) {
    for (size_t i = 0; i < arr->len; i++) {
        buf[*idx] = arr->nodes[i];
        (*idx)++;
        node_Array_toBuf(&arr->nodes[i].children, buf, idx);
    }
}


node node_process(FILE *file, node *parent, char *filename, size_t *line_num, size_t *nodes_num) {

    node this_node = {
        .parent   = parent,
        .name     = wstring_init(1),
        .desc     = wstring_init(1),
        .date     = wstring_init(1),
        .date_num = 0,
        .tag      = false,
        .text     = wstring_init(1),
        .hidden   = false,
        .children = node_Array_init(1),
        .line_num = *line_num,
        .filename = filename,
    };

    bool getting_name = true;
    bool getting_desc = false;
    bool getting_date = false;
    bool getting_tag = false;
    bool getting_text = false;

    wint_t c;
    wchar_t wc;

    wstring text_whitespace_buf = wstring_init(1);
    bool text_getting_whitespace = false;
    bool found_text_not_whitespace = false;

    while ((c = fgetwc(file)) != WEOF) {

        wc = (wchar_t)c;
        if (wc == '\n') (*line_num)++;

        if (getting_name) {
            if (wc == DLM_DESC.beg) {
                getting_name = false;
                getting_desc = true;
                continue;
            }
            if (wc == DLM_DATE.beg) {
                getting_name = false;
                getting_date = true;
                continue;
            }
            if (wc == DLM_TEXT.beg) {
                getting_name = false;
                getting_text = true;
                continue;
            }
            if (wc == DLM_TAG.beg) {
                getting_name = false;
                getting_tag = true;
                continue;
            }
            wstring_append(&this_node.name, wc);
            continue;
        }

        if (getting_desc) {
            if (wc == DLM_DESC.end) getting_desc = false;
            else {
                wstring_append(&this_node.desc, wc);
                continue;
            }
        }

        if (getting_date) {
            if (wc == DLM_DATE.end) getting_date = false;
            else {
                wstring_append(&this_node.date, wc);
                continue;
            }
        }

        if (getting_tag) {
            if (wc == DLM_TAG.end) getting_tag = false;
            else if (wc == TAG) {
                this_node.tag = true;
                continue;
            }
        }

        if (getting_text) {
            if (wc == DLM_TEXT.end) {
                getting_text = false;
                break;
            }

            if (!text_getting_whitespace) {
                if (iswspace(wc)) {
                    text_getting_whitespace = true;
                    text_whitespace_buf.len = 0;
                }
                else if (wc != NODE_MARKER) {
                    wstring_append(&this_node.text, wc);
                    found_text_not_whitespace = true;
                    continue;
                }
            }

            if (text_getting_whitespace) {
                if (iswspace(wc)) {
                    wstring_append(&text_whitespace_buf, wc);
                    continue;
                }

                text_getting_whitespace = false;

                if (wstring_containsNewline(&text_whitespace_buf)) {
                    wstring_appendNewlinesFromWstring(&this_node.text, &text_whitespace_buf);
                }
                else wstring_appendWstring(&this_node.text, &text_whitespace_buf);

                if (wc != NODE_MARKER) {
                    wstring_append(&this_node.text, wc);
                    continue;
                }
            }

        }

        if (wc == NODE_MARKER) {
            node_Array_append(&this_node.children, node_process(file, &this_node, filename, line_num, nodes_num));
            (*nodes_num)++;
            continue;
        }

        if (!getting_name && !getting_desc && !getting_date && !getting_tag && !getting_text) {
            if      (wc == DLM_DESC.beg) getting_desc = true;
            else if (wc == DLM_DATE.beg) getting_date = true;
            else if (wc == DLM_TAG.beg)  getting_tag  = true;
            else if (wc == DLM_TEXT.beg) getting_text = true;
        }

    }

    wstring_removeSurroundingWhitespace(&this_node.name);
    wstring_nullTerminate(&this_node.name);

    wstring_removeSurroundingWhitespace(&this_node.desc);
    wstring_nullTerminate(&this_node.desc);

    wstring_removeSurroundingWhitespace(&this_node.date);
    this_node.date_num = wstring_toDouble(this_node.date);

    wstring_removeSurroundingWhitespace(&this_node.text);
    wstring_nullTerminate(&this_node.text);
    // If the text consists only of whitespace, treat it as empty.
    if (!found_text_not_whitespace) this_node.text.len = 0;
    free(text_whitespace_buf.wstr);

    this_node.hidden = false;

    return this_node;
}


void node_processChildren(node *n, FILE *file, char *filename, size_t *line_num, size_t *nodes_num) {
    wint_t c;
    wchar_t wc;
    while ((c = fgetwc(file)) != WEOF) {
        wc = (wchar_t)c;
        if (wc == '\n') (*line_num)++;
        if (wc == NODE_MARKER) {
            node_Array_append(&n->children, node_process(file, n, filename, line_num, nodes_num));
            (*nodes_num)++;
        }
    }
}


void node_printFmt(node n, size_t indent_level, size_t num_current, size_t num_max) {

    if (n.hidden) return;

    for (size_t i = 0; i < indent_level; i++) putchar('\t');

    if (n.tag) {
        ansi_set("%s;%s", ANSI_BG_CYAN, ANSI_FG_BLACK);
        printf(" %lc ", TAG);
        ansi_reset();
        putchar(' ');
    }

    if (n.name.len > 0) {
        ansi_set("%s", ANSI_FMT_BOLD);
        wstring_print(n.name);
        ansi_reset();
    }
    else {
        ansi_set("%s", ANSI_BG_BLACK);
        printf("Anonymous");
        ansi_reset();
    }

    if (n.desc.len > 0) {
        printf(" | ");
        ansi_set("%s", ANSI_FG_BLUE);
        wstring_print(n.desc);
        ansi_reset();
    }

    if (n.date.len > 0) {
        printf(" | ");
        ansi_set("%s", ANSI_FG_GREEN);
        wstring_print(n.date);
        ansi_reset();
    }

    printf(" | ");
    ansi_set("%s", ANSI_FG_GREY);
    // printf("%s:", n.filename);
    // ansi_set("%s", ANSI_FMT_BOLD);
    printf("ln %ld", n.line_num);
    ansi_reset();

    putchar('\n');

    if (n.text.len > 0) {
        for (size_t i = 0; i < indent_level; i++) putchar('\t');
        for (size_t i = 0; i < n.text.len; i++) {
            printf("%lc", n.text.wstr[i]);
            if (n.text.wstr[i] == '\n') {
                for (size_t j = 0; j < indent_level; j++) putchar('\t');
            }
        }
        putchar('\n');
    }

    for (size_t i = 0; i < n.children.len; i++) {
        node_printFmt(n.children.nodes[i], indent_level + 1, i, n.children.len);
    }

    // Don't print newline if end reached
    if (num_current != num_max - 1) printf("\n");
}


int node_compareDateAscending(const void *a, const void *b) {
    return ((node *)a)->date_num - ((node *)b)->date_num;
}


int node_compareDateDescending(const void *a, const void *b) {
    return ((node *)b)->date_num - ((node *)a)->date_num;
}


void node_free(node n) {
    if (n.name.wstr != NULL) free(n.name.wstr);
    if (n.desc.wstr != NULL) free(n.desc.wstr);
    if (n.date.wstr != NULL) free(n.date.wstr);
    if (n.text.wstr != NULL) free(n.text.wstr);
    for (size_t i = 0; i < n.children.len; i++) {
        node_free(n.children.nodes[i]);
    }
    free(n.children.nodes);
}

#endif // node_IMPLEMENTATION
