const std = @import("std");
const ascii = std.ascii;

pub const TokenType = enum(u8) {
    // Single-character syntax.
    paren_left = '(',
    paren_right = ')',
    square_left = '[',
    square_right = ']',
    curly_left = '{',
    curly_right = '}',
    at = '@',
    hash = '#',
    dot = '.',
    colon = ':',
    semicolon = ';',
    equals = '=',
    plus = '+',
    minus = '-',

    invalid = 128,

    // Types.
    str,
    num,
    date,

    // Symbols.
    name,
    unresolved,

    // Directives.
    mods,
    provides,
    shares,
};

pub const Token = struct {
    token: TokenType,
    idx: u32,

    pub fn lexeme(self: Token, buf: []const u8) []const u8 {
        if (@enumToInt(self.token) <= @enumToInt(TokenType.invalid)) {
            return buf[self.idx .. self.idx + 1];
        }
        var pos: ParsePosition = .{ .buf = buf, .idx = self.idx };
        _ = pos.incSkipSymbol();
        return buf[self.idx..pos.idx];
    }
};

pub const TokenList = std.MultiArrayList(Token);

const quote_pairs = "\"'`";
pub fn parseFromBuf(
    pos: *ParsePosition,
    token_list: *TokenList,
    allocator: std.mem.Allocator,
    comptime in_node_body: bool,
) !void {
    var in_bounds = true;

    root: while (in_bounds) : (in_bounds = pos.inc()) {
        // Break into upper level if we've reached the end of the body.
        if (in_node_body and pos.byte() == '}') {
            try token_list.append(allocator, .{
                .idx = pos.*.idx,
                .token = .curly_right,
            });
            break :root;
        }

        // Don't parse quoted strings (@Node is a node, but not "@Node").
        for (quote_pairs) |quote| {
            if (pos.byte() != quote) continue;
            in_bounds = pos.inc();
            while (in_bounds and pos.byte() != quote) : (in_bounds = pos.inc()) {}
            in_bounds = pos.inc();
            break;
        }

        // Parse node name.
        if (pos.byte() != '@') continue;
        try token_list.append(allocator, .{
            .idx = pos.*.idx,
            .token = .at,
        });
        in_bounds = pos.inc();
        if (isValidSymbolChar(pos.byte())) {
            const name_start = pos.*.idx;
            while (in_bounds and isValidSymbolChar(pos.byte())) : (in_bounds = pos.inc()) {}
            try token_list.append(allocator, .{
                .idx = name_start,
                .token = .name,
            });
        }

        // Parse node contents.
        in_bounds = pos.incToNonWhitespace();
        node: while (in_bounds) : (in_bounds = pos.incSkipWhitespace()) {
            // Symbols.

            // Quoted (in which case we know it's a string).
            // TODO: Skip over escaped quotes.
            for (quote_pairs) |quote| {
                if (pos.byte() != quote) continue;
                in_bounds = pos.inc();
                const symbol_start = pos.*.idx;
                while (in_bounds and pos.byte() != quote) : (in_bounds = pos.inc()) {}
                try token_list.append(allocator, .{
                    .idx = symbol_start,
                    .token = .str,
                });
                continue :node;
            }

            // Unquoted.
            if (isValidSymbolChar(pos.byte())) {
                const symbol_start = pos.*.idx;
                while (in_bounds and isValidSymbolChar(pos.byte())) : (in_bounds = pos.inc()) {}
                try token_list.append(allocator, .{
                    .idx = symbol_start,
                    .token = .unresolved,
                });
            }

            if (!in_bounds) break;

            // Single-character syntax.
            switch (pos.byte()) {
                // If '@' was detected in this branch, it means there's a syntax error,
                // but as a favour to the AST we'll give it proper treatment anyway.
                '@' => {
                    in_bounds = pos.dec();
                    continue :root;
                },
                ';', '#', '.', ':', '=', '(', ')', '[', ']', '{', '}', '+', '-' => |byte| {
                    try token_list.append(allocator, .{
                        .idx = pos.*.idx,
                        .token = @intToEnum(TokenType, byte),
                    });
                    if (byte == '{') {
                        try parseFromBuf(pos, token_list, allocator, true);
                    }
                    // If '}' was detected in this branch, it has no matching left curly bracket,
                    // but as a favour to the AST we'll give it proper treatment anyway.
                    if (byte == '}') continue :node;
                    if (byte == ';') continue :root;
                    continue :node;
                },
                else => |byte| {
                    if (ascii.isWhitespace(byte)) continue :node;
                    try token_list.append(allocator, .{
                        .idx = pos.*.idx,
                        .token = .invalid,
                    });
                },
            } // switch(pos.byte())
        } // :node
    } // :root
} // parse()

pub const ParsePosition = struct {
    buf: []const u8 = undefined,
    idx: u32 = 0,
    fn byte(self: *ParsePosition) u8 {
        return self.buf[self.idx];
    }
    fn dec(self: *ParsePosition) bool {
        if (self.idx == 0) return false;
        self.idx -= 1;
        return true;
    }
    fn inc(self: *ParsePosition) bool {
        if (self.idx == self.buf.len - 1) return false;
        self.idx += 1;
        return true;
    }
    fn incSkipSymbol(self: *ParsePosition) bool {
        var in_bounds = self.inc();
        while (in_bounds and isValidSymbolChar(self.byte())) : (in_bounds = self.inc()) {}
        return in_bounds;
    }
    fn incSkipWhitespace(self: *ParsePosition) bool {
        var in_bounds = self.inc();
        while (in_bounds and ascii.isWhitespace(self.byte())) : (in_bounds = self.inc()) {}
        return in_bounds;
    }
    fn incToNonWhitespace(self: *ParsePosition) bool {
        var in_bounds = (self.idx < self.buf.len - 1);
        while (in_bounds and ascii.isWhitespace(self.byte())) : (in_bounds = self.inc()) {}
        return in_bounds;
    }
    fn incToValidSymbolChar(self: *ParsePosition) bool {
        var in_bounds = (self.idx < self.buf.len - 1);
        while (in_bounds and !isValidSymbolChar(self.byte())) : (in_bounds = self.inc()) {}
        return in_bounds;
    }
    fn incToWhitespace(self: *ParsePosition) bool {
        var in_bounds = self.inc();
        while (in_bounds and !ascii.isWhitespace(self.byte())) : (in_bounds = self.inc()) {}
        return in_bounds;
    }
};

fn isValidSymbolChar(x: u8) bool {
    return ascii.isAlphanumeric(x) or (x == '_') or (x == '-');
}
