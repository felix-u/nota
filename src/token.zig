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
    semicolon = ';',
    at = '@',
    hash = '#',

    // Types.
    str = 128,
    num,
    date,

    // Symbols.
    name,

    // Directives.
    mods,
    provides,
    shares,
};

pub const Token = struct {
    row: usize,
    col: usize,
    token: TokenType,
    lexeme: []const u8,
};

pub const TokenList = std.MultiArrayList(Token);

pub fn parse(buf: []const u8, token_list: *TokenList, allocator: std.mem.Allocator) !void {
    var pos = ParsePosition{ .buf = buf };

    while (pos.idx < buf.len) : (pos.increment()) {
        // Node name.
        if (pos.byte() != '@') continue;
        pos.increment();
        const name_start = pos;
        while (!ascii.isWhitespace(pos.byte())) pos.increment();
        const name_end = pos;
        try token_list.append(allocator, .{
            .row = name_start.row,
            .col = name_start.col,
            .token = .name,
            .lexeme = buf[name_start.idx..name_end.idx],
        });
    }
}

const ParsePosition = struct {
    buf: []const u8 = undefined,
    row: usize = 1,
    col: usize = 1,
    idx: usize = 0,
    fn increment(self: *ParsePosition) void {
        const c = self.buf[self.idx];
        self.idx += 1;
        if (c == '\n') self.row += 1;
        self.col = if (c == '\n') 1 else self.col + 1;
    }
    fn byte(self: *ParsePosition) u8 {
        return self.buf[self.idx];
    }
};
