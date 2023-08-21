const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");

const Writer = std.fs.File.Writer;

pub const Err = error{
    InvalidSyntax,
    NoClosingQuote,
};

pub const Kind = enum(u8) {
    chars = 128,

    // In order not to pollute this type with all the ASCII syntax characters,
    // they're not included here. Token.kind: u8 is either a syntax character
    // or an enum value below this comment.

    str,
    num,
    date,
    symbol,

    eof,
};

pub const Token = struct {
    kind: u8 = 0,
    beg_i: u32 = 0,
    end_i: u32 = 0,

    const Self = @This();

    pub fn lexeme(self: *const Self, set: *parse.Set) []const u8 {
        return set.buf[self.beg_i..self.end_i];
    }
};

pub fn parseToksFromBuf(err_writer: Writer, set: *parse.Set) !void {
    const allocator = set.allocator;
    const it = &set.buf_it;
    var last_i = it.i;

    chars: while (it.nextCodepoint()) |c1| : (last_i = it.i) {
        switch (c1) {
            '\r', '\n', '\t', ' ' => {},
            '{', '}', ':', '=', '.' => {
                try set.toks.append(allocator, .{
                    .beg_i = @intCast(last_i),
                    .end_i = @intCast(it.i),
                    .kind = set.buf[last_i],
                });
            },
            '/' => {
                if (set.buf[it.i] != '/') return log.reportErr(
                    err_writer,
                    Err.InvalidSyntax,
                    set,
                    @intCast(last_i),
                );

                last_i = it.i;
                if (it.nextCodepoint() == null) break :chars;
                while (it.nextCodepoint()) |c2| : (last_i = it.i) {
                    if (c2 == '\n') break;
                }
            },
            '"' => {
                const beg_i = it.i + 1;
                while (it.nextCodepoint()) |c2| : (last_i = it.i) {
                    if (set.buf[it.i] == '\n') return log.reportErr(
                        err_writer,
                        Err.NoClosingQuote,
                        set,
                        @as(u32, @intCast(it.i)) - 1,
                    );

                    if (set.buf[it.i] != '"' or c2 == '\\') continue;
                    last_i = it.i;
                    if (it.nextCodepoint() == null) break :chars;
                    break;
                }

                try set.toks.append(allocator, .{
                    .beg_i = @intCast(beg_i - 1),
                    .end_i = @intCast(last_i),
                    .kind = @intFromEnum(Kind.str),
                });
            },
            else => {
                if (!parse.isValidSymbolChar(@intCast(c1))) return log.reportErr(
                    err_writer,
                    Err.InvalidSyntax,
                    set,
                    @intCast(last_i),
                );

                const beg_i: u32 = @intCast(last_i);
                var this_kind: Kind =
                    if (c1 >= '0' and c1 <= '9') .num else .symbol;
                if (parse.isValidSymbolChar(it.peek(1)[0])) {
                    while (it.nextCodepoint()) |c2| : (last_i = it.i) {
                        if (c2 == '-') this_kind = .date;
                        if (!parse.isValidSymbolChar(it.peek(1)[0])) break;
                    }
                }
                try set.toks.append(allocator, .{
                    .beg_i = beg_i,
                    .end_i = @intCast(it.i),
                    .kind = @intFromEnum(this_kind),
                });
            },
        }
    }

    try set.toks.append(allocator, .{
        .beg_i = if (it.i > 0) @intCast(set.buf.len - 1) else 0,
        .end_i = if (it.i > 0) @intCast(set.buf.len - 1) else 0,
        .kind = @intFromEnum(Kind.eof),
    });
}
