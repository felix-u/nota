#include <wchar.h>
#include <wctype.h>


typedef struct {
    wint_t beg;
    wint_t end;
} DelimiterSet;

const wint_t NODE_MARKER = '@';
const DelimiterSet DLM_DESC = {'(', ')'};
const DelimiterSet DLM_DATE = {'[', ']'};
const DelimiterSet DLM_TEXT = {'{', '}'};
