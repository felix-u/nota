typedef enum Token_Type {
    token_nil = 0,
    // ASCII: <128
    token_ascii_end = 128,
    token_symbol,
    token_string,
    token_number,
    token_bool,
} Token_Type;
typedef struct Token {
    Token_Type type;
    u32 beg_i;
    u32 end_i;
} Token;
typedef Slice(Token) Slice_Token;

typedef enum Node_Type {
    node_nil = 0,
    node_decl,
} Node_Type;
typedef u32 Node_Index;
typedef struct Node {
    Node_Type type;
    Node_Index lhs;
    Node_Index rhs;
} Node;
typedef Slice(Node) Slice_Node;

typedef struct Context {
    Arena arena;
    char *path;
    Str8 bytes;
    Slice_Token tokens;
    u32 token_i;
    Slice_Node nodes;
} Context;

const bool char_is_num[256] = {
    ['0'] = 1, ['1'] = 1, ['2'] = 1, ['3'] = 1, ['4'] = 1, 
    ['5'] = 1, ['6'] = 1, ['7'] = 1, ['8'] = 1, ['9'] = 1, 
};

static bool char_is_alpha(u8 c) {
    return ('A' <= c && c <= 'Z') || ('a' <= c && c <= 'z');
}

static inline Str8 token_lexeme(Context *ctx, Token token) {
    return str8_range(ctx->bytes, token.beg_i, token.end_i);
}

static Slice_Token tokens_from_bytes(Context *ctx) {
    Slice_Token tokens = {0};
    tokens.ptr = arena_alloc(&ctx->arena, ctx->bytes.len, sizeof(Token));

    u8 *buf = ctx->bytes.ptr;
    u32 len = (u32)ctx->bytes.len;
    for (u32 i = 0; i < len; i += 1) {
        if (char_is_num[buf[i]]) {
            u32 beg_i = i;   
            while (i < len && char_is_num[buf[i]]) i += 1;
            u32 end_i = i;
            Token number = { 
                .type = token_number, 
                .beg_i = beg_i, 
                .end_i = end_i,
            };
            slice_push(tokens, number);
        } else if (char_is_alpha(buf[i])) {
            u32 beg_i = i;
            while (i < len && char_is_alpha(buf[i])) i += 1;
            u32 end_i = i;
            Token symbol = {
                .type = token_symbol,
                .beg_i = beg_i,
                .end_i = end_i,
            };
            slice_push(tokens, symbol);
        }

        switch (buf[i]) {
            case ' ': case '\t': case '\n': case '\r': {
                continue; 
            } break;
            case '/': {
                i += 1;        
                if (i < len && buf[i] == '/') {
                    while (i < len && buf[i] != '\n') i += 1;
                    goto next_char;
                }
                Token syntax_char = {
                    .type = buf[i],
                    .beg_i = i,
                    .end_i = i + 1,
                };
                slice_push(tokens, syntax_char);
            } break;
            case '"': {
                i += 1;
                u32 beg_i = i;
                for (; i < len; i += 1) {
                    if (buf[i] != '"') continue;
                    u32 end_i = i;
                    Token string = {
                        .type = token_string,
                        .beg_i = beg_i,
                        .end_i = end_i,
                    };
                    slice_push(tokens, string);
                    goto next_char;
                }
                errf("string at byte index %d does not terminate", beg_i);
                return (Slice_Token){0};
            } break;
            case '{': case '}':
            case '=': {
                Token syntax_char = {
                    .type = buf[i],
                    .beg_i = i,
                    .end_i = i + 1,
                };
                slice_push(tokens, syntax_char);
            }
        }
        next_char: continue;
    }

    return tokens;
}

static Slice_Node parse_in_body(Context *ctx, Slice_Node nodes, u32 *i) {
    (void)nodes;
    err("unimplemented");
    goto error;

    error:
    *i = (u32)ctx->tokens.len;
    return (Slice_Node){0};
}

static Slice_Node nodes_from_tokens(Context *ctx) {
    Slice_Node nodes = {0};
    nodes.ptr = arena_alloc(&ctx->arena, ctx->tokens.len, sizeof(Node));

    for (u32 *i = &ctx->token_i; *i < ctx->tokens.len; *i += 1) {
        switch (ctx->tokens.ptr[*i].type) {
            case token_symbol: {
                // switch (token_next(ctx).type) {
                //     case '=': {
                //         nodes = parse_decl(ctx);
                //     } break;
                //     case '{': {
                //         nodes = parse_node(ctx);
                //     } break;
                //     default: {
                //         errf("expected '=' or open curly; other at %d", *i);
                //         return nil_array;
                //     }
                // }
            } break;
            default: {
                errf("expected symbol; other at %d", *i);
                return (Slice_Node){0};
            }
        }
        nodes = parse_in_body(ctx, nodes, i);
    }

    return nodes;
}
