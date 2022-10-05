#include <stdio.h>
#include <wctype.h>

#include "../deps/stb_ds-v0.67/stb_ds.h"


void printls(wint_t *lstr) {
    for (int i = 0; i < arrlen(lstr); i++) printf("%lc", lstr[i]);
}
