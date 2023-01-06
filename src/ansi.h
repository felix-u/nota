#include <stdarg.h>
#include <stdbool.h>
#include <strings.h>
#include <stdio.h>
#include <unistd.h>


#ifndef ANSI_CODES
#define ANSI_CODES

const char ANSI_BEG[] = "\x1b[";
const char ANSI_END[] = "m";

const char ANSI_FG_BLACK[]          =  "30";
const char ANSI_FG_RED[]            =  "31";
const char ANSI_FG_GREEN[]          =  "32";
const char ANSI_FG_YELLOW[]         =  "33";
const char ANSI_FG_BLUE[]           =  "34";
const char ANSI_FG_MAGENTA[]        =  "35";
const char ANSI_FG_CYAN[]           =  "36";
const char ANSI_FG_GREY[]           =  "37";
const char ANSI_FG_BLACK_BRIGHT[]   =  "90";
const char ANSI_FG_RED_BRIGHT[]     =  "91";
const char ANSI_FG_YELLOW_BRIGHT[]  =  "92";
const char ANSI_FG_GREEN_BRIGHT[]   =  "93";
const char ANSI_FG_BLUE_BRIGHT[]    =  "94";
const char ANSI_FG_MAGENTA_BRIGHT[] =  "95";
const char ANSI_FG_CYAN_BRIGHT[]    =  "96";
const char ANSI_FG_GREY_BRIGHT[]    =  "97";

const char ANSI_BG_BLACK[]          =  "40";
const char ANSI_BG_RED[]            =  "41";
const char ANSI_BG_GREEN[]          =  "42";
const char ANSI_BG_YELLOW[]         =  "43";
const char ANSI_BG_BLUE[]           =  "44";
const char ANSI_BG_MAGENTA[]        =  "45";
const char ANSI_BG_CYAN[]           =  "46";
const char ANSI_BG_GREY[]           =  "47";
const char ANSI_BG_BLACK_BRIGHT[]   = "100";
const char ANSI_BG_RED_BRIGHT[]     = "101";
const char ANSI_BG_YELLOW_BRIGHT[]  = "102";
const char ANSI_BG_GREEN_BRIGHT[]   = "103";
const char ANSI_BG_BLUE_BRIGHT[]    = "104";
const char ANSI_BG_MAGENTA_BRIGHT[] = "105";
const char ANSI_BG_CYAN_BRIGHT[]    = "106";
const char ANSI_BG_GREY_BRIGHT[]    = "107";

const char ANSI_FMT_RESET[]     =  "0";
const char ANSI_FMT_BOLD[]      =  "1";
const char ANSI_FMT_ITALIC[]    =  "3";
const char ANSI_FMT_UNDERLINE[] =  "4";
const char ANSI_FMT_NORMAL[]    = "22";

#endif // ANSI_CODES


#ifndef ANSI_STATE
#define ANSI_STATE

bool ansi_enabled = false;

#endif // ANSI_STATE


void ansi_reset(void);
void ansi_set(const char *str, ...);
void ansi_stateSet(void);


#ifdef ANSI_IMPLEMENTATION

void ansi_reset(void) {
    if (ansi_enabled) printf("%s%s%s", ANSI_BEG, ANSI_FMT_RESET, ANSI_END);
}


void ansi_set(const char *str, ...) {
    va_list args;
    va_start(args, str);

    if (ansi_enabled) {
        printf(ANSI_BEG);
        vprintf(str, args);
        printf(ANSI_END);
    }

    va_end(args);
}


void ansi_stateSet(void) {
    if (isatty(STDOUT_FILENO)
     && getenv("NO_COLOR") == NULL && getenv("NO_COLOUR") == NULL
     && strncasecmp(getenv("TERM"), "dumb", 4))
    {
        ansi_enabled = true;
    }
}

#endif // ANSI_IMPLEMENTATION
