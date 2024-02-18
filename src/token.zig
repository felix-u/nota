const Context = @import("Context.zig");
const std = @import("std");

const Writer = std.fs.File.Writer;

pub const Kind = enum(u8) {
    none = 0,
    chars = 128,

    // In order not to pollute this type with all the ASCII syntax characters,
    // they're not included here. Token.kind: u8 is either a syntax character
    // or an enum value below this comment.

    keyword_beg,
    keyword_const,
    keyword_node,
    keyword_end,

    str,
    ident,

    eof,

    // Resolved only during AST construction
    builtin_run,

    pub fn isKeyword(literal: []const u8) ?@This() {
        if (std.mem.eql(u8, literal, "const")) {
            return .keyword_const;
        } else if (std.mem.eql(u8, literal, "node")) {
            return .keyword_node;
        } else return null;
    }

    pub fn isBuiltin(literal: []const u8) ?@This() {
        const pre = "@";
        if (std.mem.eql(u8, literal, pre ++ "run")) {
            return .builtin_run;
        } else return null;
    }
};

pub const Token = struct {
    kind: u8 = 0,
    beg_i: u32 = 0,
    end_i: u32 = 0,

    pub inline fn isEof(self: @This()) bool {
        return self.kind == @intFromEnum(Kind.eof);
    }
};

fn toksAppendCharHere(ctx: *Context, kind: u21) !void {
    try ctx.toks.append(ctx.allocator, .{
        .beg_i = @intCast(ctx.buf_it.i - 1),
        .end_i = @intCast(ctx.buf_it.i),
        .kind = @intCast(kind),
    });
}

inline fn isValidSymbolChar(c: u21) bool {
    return switch (c) {
        '_',
        '0'...'9',
        'A'...'Z',
        'a'...'z',
        => true,
        else => false,
    };
}

pub fn parseToksFromBuf(ctx: *Context) !void {
    const allocator = ctx.allocator;
    const it = &ctx.buf_it;
    var last_i = it.i;

    chars: while (it.nextCodepoint()) |c1| : (last_i = it.i) switch (c1) {
        '\r', '\t', ' ', '\n' => continue,
        '(', ')' => try toksAppendCharHere(ctx, c1),
        '/' => {
            if (ctx.buf[it.i] != '/') {
                try toksAppendCharHere(ctx, c1);
                return ctx.err(
                    "invalid '/'; did you mean '//' to start a comment?",
                    .{},
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
                    return ctx.err(
                        "expected '\"' to end string before newline " ++
                            "(multiline strings not yet implemented)",
                        .{},
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
            if (c1 != '@' and !isValidSymbolChar(@intCast(c1))) {
                try toksAppendCharHere(ctx, c1);
                return ctx.err(
                    "'{c}' is invalid syntax",
                    .{std.math.lossyCast(u8, c1)},
                );
            }

            const beg_i: u32 = @intCast(last_i);

            if (isValidSymbolChar(it.peek(1)[0])) {
                while (it.nextCodepoint()) |_| : (last_i = it.i) {
                    if (!isValidSymbolChar(it.peek(1)[0])) break;
                }
            }
            const end_i = it.i;
            const lexeme = ctx.buf[beg_i..end_i];

            const new_tok = Token{
                .beg_i = beg_i,
                .end_i = @intCast(end_i),
                .kind = if (Kind.isKeyword(lexeme)) |keyword|
                    @intFromEnum(keyword)
                else
                    @intFromEnum(Kind.ident),
            };

            try ctx.toks.append(allocator, new_tok);
        },
    };

    try ctx.toks.append(allocator, .{
        .beg_i = if (it.i > 0) @intCast(ctx.buf.len - 1) else 0,
        .end_i = if (it.i > 0) @intCast(ctx.buf.len - 1) else 0,
        .kind = @intFromEnum(Kind.eof),
    });
}
