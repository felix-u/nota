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
    invalid,

    // Types.
    str = 128,
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
    pos: ParsePosition,
    token: TokenType,
    lexeme: []const u8,
};

pub const TokenList = std.MultiArrayList(Token);

const quote_pairs = "\"'`";
pub fn parse(pos: *ParsePosition, token_list: *TokenList, allocator: std.mem.Allocator) !void {
    var in_bounds = true;

    root: while (in_bounds) : (in_bounds = pos.inc()) {
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
            .pos = pos.*,
            .token = .at,
            .lexeme = pos.buf[pos.idx .. pos.idx + 1],
        });
        in_bounds = pos.inc();
        const name_start = pos.*;
        while (in_bounds and isValidSymbolChar(pos.byte())) : (in_bounds = pos.inc()) {}
        const name_end = pos.*;
        try token_list.append(allocator, .{
            .pos = name_start,
            .token = .name,
            .lexeme = pos.buf[name_start.idx..name_end.idx],
        });

        // Parse node contents.
        in_bounds = pos.incSkipWhitespace();
        node: while (in_bounds) : (in_bounds = pos.incSkipWhitespace()) {
            // Symbols.

            // Quoted (in which case we know it's a string).
            // TODO: Skip over escaped quotes.
            for (quote_pairs) |quote| {
                if (pos.byte() != quote) continue;
                in_bounds = pos.inc();
                const symbol_start = pos.*;
                while (in_bounds and pos.byte() != quote) : (in_bounds = pos.inc()) {}
                const symbol_end = pos.*;
                try token_list.append(allocator, .{
                    .pos = symbol_start,
                    .token = .str,
                    .lexeme = pos.buf[symbol_start.idx..symbol_end.idx],
                });
                continue :node;
            }

            // Unquoted.
            if (isValidSymbolChar(pos.byte())) {
                const symbol_start = pos.*;
                while (in_bounds and isValidSymbolChar(pos.byte())) : (in_bounds = pos.inc()) {}
                const symbol_end = pos.*;
                try token_list.append(allocator, .{
                    .pos = symbol_start,
                    .token = .unresolved,
                    .lexeme = pos.buf[symbol_start.idx..symbol_end.idx],
                });
            }

            if (!in_bounds) break;

            // Single-character syntax.
            switch (pos.byte()) {
                ';', '#', '.', ':', '=', '(', ')', '[', ']', '{', '}' => |byte| {
                    try token_list.append(allocator, .{
                        .pos = pos.*,
                        .token = @intToEnum(TokenType, byte),
                        .lexeme = pos.buf[pos.idx .. pos.idx + 1],
                    });
                    if (byte == '{') try parse(pos, token_list, allocator);
                    if (byte == '}') break :root;
                    if (byte == ';') continue :root;
                    continue :node;
                },
                else => |byte| {
                    if (ascii.isWhitespace(byte)) continue :node;
                    try token_list.append(allocator, .{
                        .pos = pos.*,
                        .token = .invalid,
                        .lexeme = pos.buf[pos.idx .. pos.idx + 1],
                    });
                },
            } // switch(pos.byte())
        } // :node
    } // :root
} // parse()

pub const ParsePosition = struct {
    buf: []const u8 = undefined,
    row: usize = 1,
    col: usize = 1,
    idx: usize = 0,
    fn byte(self: *ParsePosition) u8 {
        return self.buf[self.idx];
    }
    fn inc(self: *ParsePosition) bool {
        if (self.idx == self.buf.len - 1) return false;
        const prev_byte = self.byte();
        self.idx += 1;
        if (prev_byte == '\n') {
            self.row += 1;
            self.col = 1;
        } else self.col += 1;
        return true;
    }
    fn incSkipWhitespace(self: *ParsePosition) bool {
        var in_bounds = self.inc();
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
