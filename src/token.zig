const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");

const Writer = std.fs.File.Writer;

pub const Err = error{
    InvalidSyntax,
    NoClosingQuote,
};

pub const Kind = enum(u8) {
    none = 0,
    chars = 128,

    // In order not to pollute this type with all the ASCII syntax characters,
    // they're not included here. Token.kind: u8 is either a syntax character
    // or an enum value below this comment.

    str,
    num,
    date,
    symbol,
    true,
    false,

    eof,

    // Mostly used by AST later.

    op_beg,
    equals,
    op_end,

    keyword_beg,

    control,
    @"for",
    control_end,

    keyword_end,
};

pub const Token = struct {
    kind: u8 = 0,
    beg_i: u32 = 0,
    end_i: u32 = 0,

    const Self = @This();

    pub fn lexeme(self: *const Self, ctx: *parse.Context) []const u8 {
        return ctx.buf[self.beg_i..self.end_i];
    }
};

pub fn parseToksFromBuf(err_writer: Writer, ctx: *parse.Context) !void {
    const allocator = ctx.allocator;
    const it = &ctx.buf_it;
    var last_i = it.i;

    chars: while (it.nextCodepoint()) |c1| : (last_i = it.i) switch (c1) {
        '\r', '\n', '\t', ' ' => {},
        '=' => {
            const next = it.nextCodepoint();
            if (next == null) break :chars;
            if (next.? == '=') try ctx.toks.append(allocator, .{
                .beg_i = @intCast(last_i),
                .end_i = @intCast(it.i),
                .kind = @intFromEnum(Kind.equals),
            }) else try ctx.toks.append(allocator, .{
                .beg_i = @intCast(last_i),
                .end_i = @intCast(last_i + 1),
                .kind = ctx.buf[last_i],
            });
        },
        '{', '}', '(', ')', ';', ':', '!', '>', '<', '@', '|' => {
            try ctx.toks.append(allocator, .{
                .beg_i = @intCast(last_i),
                .end_i = @intCast(it.i),
                .kind = @intCast(c1),
            });
        },
        '/' => {
            if (ctx.buf[it.i] != '/') {
                try ctx.toks.append(allocator, .{
                    .beg_i = @intCast(last_i),
                    .end_i = @intCast(last_i + 1),
                    .kind = @intCast(c1),
                });
                return log.reportErr(
                    err_writer,
                    Err.InvalidSyntax,
                    ctx,
                    @intCast(ctx.toks.len - 1),
                );
            }

            last_i = it.i;
            if (it.nextCodepoint() == null) break :chars;
            while (it.nextCodepoint()) |c2| : (last_i = it.i) {
                if (c2 == '\n') break;
            }
        },
        '"' => {
            const beg_i = it.i + 1;
            while (it.nextCodepoint()) |c2| : (last_i = it.i) {
                if (ctx.buf[it.i] == '\n') {
                    try ctx.toks.append(allocator, .{
                        .beg_i = @intCast(last_i),
                        .end_i = @intCast(last_i + 1),
                        .kind = @intCast(c1),
                    });
                    return log.reportErr(
                        err_writer,
                        Err.NoClosingQuote,
                        ctx,
                        @intCast(ctx.toks.len - 1),
                    );
                }

                if (ctx.buf[it.i] != '"' or c2 == '\\') continue;
                last_i = it.i;
                if (it.nextCodepoint() == null) break :chars;
                break;
            }

            try ctx.toks.append(allocator, .{
                .beg_i = @intCast(beg_i - 1),
                .end_i = @intCast(last_i),
                .kind = @intFromEnum(Kind.str),
            });
        },
        else => {
            if (!parse.isValidSymbolChar(@intCast(c1))) {
                try ctx.toks.append(allocator, .{
                    .beg_i = @intCast(last_i),
                    .end_i = @intCast(last_i + 1),
                    .kind = @intCast(c1),
                });
                return log.reportErr(
                    err_writer,
                    Err.InvalidSyntax,
                    ctx,
                    @intCast(ctx.toks.len - 1),
                );
            }

            const beg_i: u32 = @intCast(last_i);

            var this_kind: Kind = .symbol;
            if (c1 >= '0' and c1 <= '9') this_kind = .num;

            if (parse.isValidSymbolChar(it.peek(1)[0])) {
                while (it.nextCodepoint()) |c2| : (last_i = it.i) {
                    if (c2 == '-') this_kind = .date;
                    if (!parse.isValidSymbolChar(it.peek(1)[0])) break;
                }
            }

            const keyword = parse.keyword(ctx.buf[beg_i..it.i]);
            this_kind = switch (keyword) {
                .true, .false, .@"for" => keyword,
                else => this_kind,
            };

            try ctx.toks.append(allocator, .{
                .beg_i = beg_i,
                .end_i = @intCast(it.i),
                .kind = @intFromEnum(this_kind),
            });
        },
    };

    try ctx.toks.append(allocator, .{
        .beg_i = if (it.i > 0) @intCast(ctx.buf.len - 1) else 0,
        .end_i = if (it.i > 0) @intCast(ctx.buf.len - 1) else 0,
        .kind = @intFromEnum(Kind.eof),
    });
}
