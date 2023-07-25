const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");

pub const Err = error{
    InvalidSyntax,
    NoClosingQuote,
};

pub const Kind = enum(u8) {
    nil = 0,

    curly_left = '{',
    curly_right = '}',
    colon = ':',
    equals = '=',
    dot = '.',

    chars = 128,

    str,
    num,
    date,
    symbol,

    eof,
};

pub const Token = struct {
    kind: Kind = .nil,
    beg_i: u32 = 0,
    end_i: u32 = 0,

    const Self = @This();

    pub fn lexeme(self: *const Self, set: *parse.Set) []const u8 {
        return set.buf[self.beg_i..self.end_i];
    }
};

pub fn parseBuf(err_writer: std.fs.File.Writer, set: *parse.Set) !void {
    const allocator = set.allocator;
    const it = &set.buf_it;

    chars: while (it.nextCodepoint()) |c1| switch (c1) {
        '\n', '\t', ' ' => {},
        '{', '}', ':', '=', '.' => {
            try set.toks.append(allocator, .{
                .beg_i = @intCast(it.i - 1),
                .end_i = @intCast(it.i),
                .kind = @enumFromInt(set.buf[it.i - 1]),
            });
        },
        '/' => {
            if (it.peek(1)[0] != '/') return log.reportErr(
                err_writer,
                Err.InvalidSyntax,
                set,
                @intCast(it.i - 1),
            );

            if (it.nextCodepoint() == null) break :chars;
            while (it.nextCodepoint()) |c2| if (c2 == '\n') break;
        },
        '"' => {
            const beg_i = it.i + 1;
            while (it.nextCodepoint()) |c2| {
                if (it.peek(1)[0] == '\n') return log.reportErr(
                    err_writer,
                    Err.NoClosingQuote,
                    set,
                    @as(u32, @intCast(it.i)) - 1,
                );

                if (it.peek(1)[0] != '"' or c2 == '\\') continue;
                if (it.nextCodepoint() == null) break :chars;
                break;
            }

            try set.toks.append(allocator, .{
                .beg_i = @intCast(beg_i - 1),
                .end_i = @intCast(it.i - 1),
                .kind = .str,
            });
        },
        else => {
            if (!parse.isValidSymbolChar(@intCast(c1))) return log.reportErr(
                err_writer,
                Err.InvalidSyntax,
                set,
                @intCast(it.i - 1),
            );

            const beg_i: u32 = @intCast(it.i - 1);
            var this_kind: Kind =
                if (c1 >= '0' and c1 <= '9') .num else .symbol;
            if (parse.isValidSymbolChar(it.peek(1)[0])) {
                while (it.nextCodepoint()) |c2| {
                    if (c2 == '-') this_kind = .date;
                    if (!parse.isValidSymbolChar(it.peek(1)[0])) break;
                }
            }
            try set.toks.append(allocator, .{
                .beg_i = beg_i,
                .end_i = @intCast(it.i),
                .kind = this_kind,
            });
        },
    };

    try set.toks.append(allocator, .{
        .beg_i = if (it.i > 0) @intCast(it.i - 1) else 0,
        .end_i = if (it.i > 0) @intCast(it.i - 1) else 0,
        .kind = .eof,
    });
}
