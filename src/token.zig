const std = @import("std");

pub const TokenType = enum(u8) {
    // Single-character syntax
    paren_left = '(',
    paren_right = ')',
    square_left = '[',
    square_right = ']',
    curly_left = '{',
    curly_right = '}',
    semicolon = ';',
    at = '@',
    hash = '#',

    // Types
    str = 128,
    num,
    date,

    // Directives
    mods,
    provides,
    shares,
};

pub const Token = struct {
    row: usize,
    col: usize,
    tok: TokenType,
    lexeme_start: usize,
    lexeme_end: usize,
};

pub const TokenList = std.MultiArrayList(Token);

pub fn parse(buf: []const u8, token_list: *TokenList) !void {
    std.debug.print("{s}", .{buf});
    _ = token_list;
}
