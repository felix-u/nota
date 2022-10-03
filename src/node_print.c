#include <stdio.h>
#include <wctype.h>

#ifndef STB_DS_IMPLEMENTATION
#define STB_DS_IMPLEMENTATION
#include "../deps/stb_ds-v0.67/stb_ds.h"
#endif


void printls(wint_t *lstr) {
    for (int i = 0; i < arrlen(lstr); i++) printf("%lc", lstr[i]);
}
