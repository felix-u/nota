#include <stdbool.h>
#include <stdio.h>
#include <wchar.h>
#include <wctype.h>

#include "node_print.c"

#include "../deps/stb_ds-v0.67/stb_ds.h"


typedef struct Node {
    struct Node *parent;
    wint_t *name;
    wint_t *desc;
    wint_t *date;
    wint_t *text;
    struct Node *children;
} Node;

typedef struct Delimiter {
    wint_t beg;
    wint_t end;
} Delimiter;

const wint_t NODE_CHAR = '@';
const Delimiter DESC_DLM = { '(', ')' };
const Delimiter DATE_DLM = { '[', ']' };
const Delimiter NODE_DLM = { '{', '}' };


bool isWhiteSpace(char c) {
    if (c == ' ' || c == '\n' || c == '\t') return true;
    return false;
}


Node processNode(Node *parent_node, FILE *file) {
    wint_t *desc = NULL;
    wint_t *name = NULL;
    wint_t *date = NULL;
    wint_t *text = NULL;
    Node *child_nodes = NULL;
    bool getting_name = false;
    bool getting_desc = false;
    bool getting_date = false;
    bool getting_text = false;

    wint_t c;
    while ((c = fgetwc(file)) != WEOF) {
        if (getting_name == true) {
            if (isWhiteSpace(c) || c == DESC_DLM.beg || c == DATE_DLM.beg || c == NODE_DLM.beg) getting_name = false;
            else arrput(name, c);
        }
        else if (getting_desc == true) {
            if (c == DESC_DLM.end) getting_desc = false;
            else arrput(desc, c);
        }
        else if (getting_date == true) {
            if (c == DATE_DLM.end) getting_date = false;
            else arrput(date, c);
        }

        if (c == NODE_CHAR) getting_name = true;
        else if (c == DESC_DLM.beg) getting_desc = true;
        else if (c == DATE_DLM.beg) getting_date = true;
        else if (c == NODE_DLM.beg) {
            arrput(child_nodes, processNode(parent_node, file));
        }
        else if (c == NODE_DLM.end) break;
        else arrput(text, c);
    }

    Node node_return = {
        parent_node,
        name,
        desc,
        date,
        text,
        child_nodes
    };

    // DEBUG
    printls(node_return.name);
    putchar('\n');
    printls(node_return.desc);
    putchar('\n');
    printls(node_return.date);
    putchar('\n');

    // @Missing { None of this allocated memory is ever freed! }

    // arrfree(parent_node);
    // arrfree(name);
    // arrfree(desc);
    // arrfree(date);
    // arrfree(text);
    // arrfree(child_nodes);

    return node_return;
}
