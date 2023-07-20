const std = @import("std");
const log = @import("log.zig");
const parse = @import("parse.zig");

pub const Kind = enum(u8) {
    curly_left = '{',
    curly_right = '}',
    colon = ':',
    equals = '=',
    dot = '.',

    chars = 128,

    str,
    symbol,

    eof,
};

pub const Token = struct {
    kind: Kind,
    beg_i: u32,
    end_i: u32,
};

pub const TokenList = std.MultiArrayList(Token);

const quote_pairs = "\"'`";

pub fn fromBufAlloc(allocator: std.mem.Allocator, errWriter: std.fs.File.Writer, set: *parse.Set) !void {
    const it = &set.buf_it;

    chars: while (it.nextCodepoint()) |c1| {
        inline for (quote_pairs) |quote| {
            if (c1 == quote) {
                const beg_i = it.i + 1;

                str: while (it.nextCodepoint()) |c2| {
                    if (it.peek(1)[0] == '\n') return log.reportErr(
                        errWriter,
                        log.SyntaxErr.NoClosingQuote,
                        set,
                        @as(u32, @intCast(it.i)) - 1,
                    );

                    if (c2 == '\\' or it.peek(1)[0] != quote) continue :str;
                    if (it.nextCodepoint() == null) break :chars;
                    break :str;
                }

                try set.toks.append(allocator, .{
                    .beg_i = @intCast(beg_i - 1),
                    .end_i = @intCast(it.i - 1),
                    .kind = .str,
                });
                continue :chars;
            }
        }

        switch (c1) {
            '\n', '\t', ' ' => {},
            '{', '}', ':', '=', '.' => {
                try set.toks.append(allocator, .{
                    .beg_i = @intCast(it.i - 1),
                    .end_i = @intCast(it.i),
                    .kind = @enumFromInt(set.buf[it.i - 1]),
                });
            },
            '/' => {
                if (it.peek(1)[0] != '/') {
                    return log.reportErr(errWriter, log.SyntaxErr.InvalidSyntax, set, @intCast(it.i - 1));
                }
                if (it.nextCodepoint() == null) break :chars;
                while (it.nextCodepoint()) |c2| {
                    if (c2 == '\n') break;
                }
            },
            else => {
                if (!parse.isValidSymbolChar(@intCast(c1))) {
                    return log.reportErr(errWriter, log.SyntaxErr.InvalidSyntax, set, @intCast(it.i - 1));
                }
                const beg_i: u32 = @intCast(it.i - 1);
                while (it.nextCodepoint()) |_| {
                    if (!parse.isValidSymbolChar(it.peek(1)[0])) break;
                }
                try set.toks.append(allocator, .{ .beg_i = beg_i, .end_i = @intCast(it.i), .kind = .symbol });
            },
        }
    }

    try set.toks.append(allocator, .{ .beg_i = @intCast(it.i - 1), .end_i = @intCast(it.i - 1), .kind = .eof });
}
