const std = @import("std");
const log = @import("log.zig");
const parse = @import("parse.zig");

const ascii = std.ascii;

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
    idx: u32,
};

pub const TokenList = std.MultiArrayList(Token);

const quote_pairs = "\"'`";

pub fn fromBufAlloc(
    allocator: std.mem.Allocator,
    errWriter: std.fs.File.Writer,
    set: *parse.Set,
) !void {
    const it = &set.buf_it;

    chars: while (it.nextCodepoint()) |*c| {
        inline for (quote_pairs) |quote| {
            if (c == quote) {
                const beg_i = it.i;

                c = it.nextCodepoint() orelse break :chars;

                while (it.nextCodepoint() != null) : (c = set.buf[it.i]) {
                    if (c == '\n') return log.reportErr(
                        errWriter,
                        log.SyntaxErr.NoClosingQuote,
                        set,
                        @as(u32, @intCast(it.i)) - 2,
                    );

                    if (c != '\\' and it.peek(1)[0] == quote) break;
                }

                try set.toks.append(allocator, .{ .idx = @intCast(beg_i - 1), .kind = .str });
                continue :chars;
            }
        }

        switch (c) {
            '\n', '\t', ' ' => {},
            '{', '}', ':', '=', '.' => {
                try set.toks.append(allocator, .{ .idx = @intCast(it.i - 1), .kind = @enumFromInt(set.buf[it.i - 1]) });
            },
            '/' => {
                if (it.peek(1)[0] != '/') {
                    return log.reportErr(errWriter, log.SyntaxErr.InvalidSyntax, set, @intCast(it.i - 1));
                }
                c = it.nextCodepoint() orelse break :chars;
                while (it.nextCodepoint() != null and set.buf[it.i - 1] != '\n') {}
            },
            else => {
                if (!parse.isValidSymbolChar(it.peek(1)[0])) {
                    return log.reportErr(errWriter, log.SyntaxErr.InvalidSyntax, set, @intCast(it.i - 1));
                }
                try set.toks.append(allocator, .{ .idx = @intCast(it.i - 1), .kind = .symbol });
                c = it.nextCodepoint() orelse break :chars;
                while (it.nextCodepoint() != null and parse.isValidSymbolChar(it.peek(1)[0])) {}
            },
        }
    }

    try set.toks.append(allocator, .{ .idx = @intCast(it.i - 1), .kind = .eof });
}

pub const BufIterator = struct {
    set: *parse.Set = undefined,
    idx: u32 = 0,
    const Self = @This();

    pub fn peek(self: *Self) u8 {
        return self.set.buf[self.idx];
    }

    pub fn peekNext(self: *Self) u8 {
        return if (self.idx + 1 < self.set.buf.len) self.set.buf[self.idx + 1] else 0;
    }

    pub fn peekLast(self: *Self) u8 {
        return if (self.idx > 0) self.set.buf[self.idx - 1] else 0;
    }

    pub fn skip(self: *Self) bool {
        if (self.idx + 1 == self.set.buf.len) return false;
        self.idx += 1;
        return true;
    }
};
