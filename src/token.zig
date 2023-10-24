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
    ident,
    true,
    false,

    arrow,

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
};

fn toksAppendCharHere(ctx: *parse.Context, kind: u21) !void {
    try ctx.toks.append(ctx.allocator, .{
        .beg_i = @intCast(ctx.buf_it.i - 1),
        .end_i = @intCast(ctx.buf_it.i),
        .kind = @intCast(kind),
    });
}

pub fn parseToksFromBuf(ctx: *parse.Context) !void {
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
        '{',
        '}',
        '(',
        ')',
        '[',
        ']',
        ';',
        ':',
        '!',
        '>',
        '<',
        '@',
        '|',
        '.',
        => try toksAppendCharHere(ctx, c1),
        '-' => {
            if (ctx.buf[it.i] != '>') {
                try toksAppendCharHere(ctx, c1);
                continue :chars;
            }

            if (it.nextCodepoint() == null) break :chars;
            try ctx.toks.append(allocator, .{
                .beg_i = @intCast(last_i),
                .end_i = @intCast(it.i),
                .kind = @intFromEnum(Kind.arrow),
            });
        },
        '/' => {
            if (ctx.buf[it.i] != '/') {
                try toksAppendCharHere(ctx, c1);
                return log.err(
                    ctx,
                    Err.InvalidSyntax,
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
                    try toksAppendCharHere(ctx, c1);
                    return log.err(
                        ctx,
                        Err.NoClosingQuote,
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
                try toksAppendCharHere(ctx, c1);
                return log.err(
                    ctx,
                    Err.InvalidSyntax,
                    @intCast(ctx.toks.len - 1),
                );
            }

            const beg_i: u32 = @intCast(last_i);

            var this_kind: Kind = .ident;
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

pub fn printToks(ctx: *parse.Context) !void {
    const writer = ctx.writer;

    _ = try writer.write("TOKENS:\n");

    for (0..ctx.toks.len) |i| {
        const tok = ctx.toks.get(i);
        var pos: log.filePos = .{ .ctx = ctx, .i = tok.beg_i };
        pos.computeCoords();
        if (tok.kind < 128) try writer.print(
            "{d}:{d}\t{d}\t{s}\t{c}\n",
            .{ pos.row, pos.col, i, ctx.lexeme(@intCast(i)), tok.kind },
        ) else {
            const tok_kind: Kind = @enumFromInt(tok.kind);
            try writer.print(
                "{d}:{d}\t{d}\t{s}\t{}\n",
                .{ pos.row, pos.col, i, ctx.lexeme(@intCast(i)), tok_kind },
            );
        }
    }
}
