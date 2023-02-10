#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stddef.h>
#include <unistd.h>

#include "ansi.h"
#include "sstring.h"

#ifndef node_TYPE
#define node_TYPE

typedef struct {
    uint8_t beg;
    uint8_t end;
} node_DelimiterSet;

const uint8_t NODE_MARKER = '@';
      uint8_t TAG         = 'x';

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
    sstring name;
    sstring desc;
    sstring date;
    double date_num;
    bool tag;
    sstring text;
    bool hidden;
    struct node_Array children;
} node;

#endif // node_TYPE


node_Array node_Array_init(size_t init_size);
void node_Array_append(node_Array *arr, node node);
void node_Array_toBuf(node_Array *arr, node *buf, size_t *idx);

node node_process(FILE *file, node *parent, size_t *nodes_num);
void node_processChildren(node *node, FILE *file, size_t *nodes_num);
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


node node_process(FILE *file, node *parent, size_t *nodes_num) {

    node this_node = {
        parent,           // parent
        sstring_init(1),  // name
        sstring_init(1),  // desc
        sstring_init(1),  // date
        0,                // date_num
        false,            // tag
        sstring_init(1),  // text
        false,            // hidden
        node_Array_init(1) // children
    };

    bool getting_name = true;
    bool getting_desc = false;
    bool getting_date = false;
    bool getting_tag = false;
    bool getting_text = false;

    wint_t c;
    uint8_t wc;

    sstring text_whitespace_buf = sstring_init(1);
    bool text_getting_whitespace = false;
    bool found_text_not_whitespace = false;

    while ((c = fgetwc(file)) != WEOF) {

        wc = (uint8_t)c;

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
            sstring_append(&this_node.name, wc);
            continue;
        }

        if (getting_desc) {
            if (wc == DLM_DESC.end) getting_desc = false;
            else {
                sstring_append(&this_node.desc, wc);
                continue;
            }
        }

        if (getting_date) {
            if (wc == DLM_DATE.end) getting_date = false;
            else {
                sstring_append(&this_node.date, wc);
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
                    sstring_append(&this_node.text, wc);
                    found_text_not_whitespace = true;
                    continue;
                }
            }

            if (text_getting_whitespace) {
                if (iswspace(wc)) {
                    sstring_append(&text_whitespace_buf, wc);
                    continue;
                }

                text_getting_whitespace = false;

                if (sstring_containsNewline(&text_whitespace_buf)) {
                    sstring_appendNewlinesFromsstring(&this_node.text, &text_whitespace_buf);
                }
                else sstring_appendsstring(&this_node.text, &text_whitespace_buf);

                if (wc != NODE_MARKER) {
                    sstring_append(&this_node.text, wc);
                    continue;
                }
            }

        }

        if (wc == NODE_MARKER) {
            node_Array_append(&this_node.children, node_process(file, &this_node, nodes_num));
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

    sstring_removeSurroundingWhitespace(&this_node.name);
    sstring_nullTerminate(&this_node.name);

    sstring_removeSurroundingWhitespace(&this_node.desc);
    sstring_nullTerminate(&this_node.desc);

    sstring_removeSurroundingWhitespace(&this_node.date);
    this_node.date_num = sstring_toDouble(this_node.date);

    sstring_removeSurroundingWhitespace(&this_node.text);
    sstring_nullTerminate(&this_node.text);
    // If the text consists only of whitespace, treat it as empty.
    if (!found_text_not_whitespace) this_node.text.len = 0;
    free(text_whitespace_buf.wstr);

    this_node.hidden = false;

    return this_node;
}


void node_processChildren(node *n, FILE *file, size_t *nodes_num) {
    wint_t c;
    uint8_t wc;
    while ((c = fgetwc(file)) != WEOF) {
        wc = (uint8_t)c;
        if (wc == NODE_MARKER) {
            node_Array_append(&n->children, node_process(file, n, nodes_num));
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
        sstring_print(n.name);
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
        sstring_print(n.desc);
        ansi_reset();
    }

    if (n.date.len > 0) {
        printf(" | ");
        ansi_set("%s", ANSI_FG_GREEN);
        sstring_print(n.date);
        ansi_reset();
    }

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
