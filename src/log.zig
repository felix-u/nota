const ast = @import("ast.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

pub const filePos = struct {
    ctx: *parse.Context,
    i: u32 = 0,
    row: u32 = 1,
    col: u32 = 1,

    pub fn computeCoords(self: *filePos) void {
        if (self.i == 0) return;
        var last_newline_i: u32 = 0;
        var row_num: u32 = 1;
        var i: u32 = 0;
        while (i <= self.i) : (i += 1) {
            if (self.ctx.buf[i] != '\n') continue;
            last_newline_i = i;
            row_num += 1;
        }
        self.row = row_num;
        self.col = if (row_num == 1) self.i + 1 else self.i - last_newline_i;
    }

    pub fn getLine(self: *filePos) []const u8 {
        var end_i = self.i;
        while (self.ctx.buf[end_i] != '\n' and end_i < self.ctx.buf.len) {
            end_i += 1;
        }

        var beg_i = if (self.i == 0) 0 else self.i - 1;
        while (self.ctx.buf[beg_i] != '\n' and beg_i - 1 > 0) {
            beg_i -= 1;
        }

        return self.ctx.buf[beg_i..end_i];
    }
};

pub fn reportErr(
    ctx: *parse.Context,
    comptime err: anyerror,
    tok_i: u32,
) anyerror {
    var pos = filePos{ .ctx = ctx, .i = ctx.toks.items(.beg_i)[tok_i] };
    pos.computeCoords();

    const writer = ctx.err_writer;

    try writer.print(
        "{s}:{d}:{d}: error: ",
        .{ pos.ctx.filepath, pos.row, pos.col },
    );

    switch (err) {
        inline token.Err.InvalidSyntax => {
            _ = try writer.write("invalid syntax");
        },
        inline token.Err.NoClosingQuote => {
            _ = try writer.write("expected quote to close string");
        },
        inline ast.Err.EmptyBody => {
            _ = try writer.write("empty body invalid in this context");
        },
        inline ast.Err.FloatingSymbol => {
            _ = try writer.write("expected '{' or '=' after symbol");
        },
        inline ast.Err.NoClosingCurly => {
            _ = try writer.write("expected '}' to terminate node body");
        },
        inline ast.Err.NoIteratorLabel => {
            _ = try writer.write("expected iterator label: 'for label: ...'");
        },
        inline ast.Err.NoNodeName => {
            _ = try writer.write("expected node name preceding '{'");
        },
        inline ast.Err.UnexpectedCurlyLeft => {
            _ = try writer.write("unexpected '{'");
        },
        inline ast.Err.UnexpectedKeyword => {
            _ = try writer.write("unexpected keyword");
        },
        inline ast.Err.UnmatchedCurlyRight => {
            _ = try writer.write("'}' is unmatched");
        },
        inline else => unreachable,
    }

    try writer.print("{s}\n", .{pos.getLine()});

    var space_i: u32 = 1;
    while (space_i < pos.col) : (space_i += 1) {
        try writer.writeByte(' ');
    }
    _ = try writer.write("^\n");

    return err;
}
