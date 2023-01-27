#include <stdlib.h>
#include <wchar.h>

#ifndef TOKEN_TYPE
#define TOKEN_TYPE

typedef enum token {
    // Single-character syntax
    T_PAREN_LEFT, T_PAREN_RIGHT, T_SQUARE_BRACKET_LEFT, T_SQUARE_BRACKET_RIGHT, T_COLON, T_SEMICOLON, T_AT,
    //Keywords
    T_STR, T_NUM, T_MODS, T_PROVIDES, T_INHERITS,

    T_EOF
} token;

typedef struct token_Array {
    size_t  *row;
    size_t  *col;
    token   *tok;
    wchar_t *lexeme;
} token_Array;

#endif // TOKEN_TYPE


// Function prototypes will go here


#ifdef TOKEN_IMPLEMENTATION

// Function definitions will go here

#endif // TOKEN_IMPLEMENTATION
