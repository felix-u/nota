const std = @import("std");
const parse = @import("parse.zig");

pub const SyntaxErr = error{
    AssignmentToNothing,
    ExprIsTypeName,
    InvalidSyntax,
    InvalidTypeSpecifier,
    MisplacedNode,
    NameIsKeyword,
    NoExpr,
    NoExprName,
    NoLeftParen,
    NoNodeName,
    NoRightCurly,
    NoSemicolonAfterBody,
    NoSemicolonAfterNode,
    NoTypeAfterColon,
    StrNoClosingQuote,
    Unimplemented,
};

pub const filePos = struct {
    set: *parse.Set = undefined,
    idx: u32 = 0,
    line: u32 = 1,
    col: u32 = 1,

    pub fn computeCoords(self: *filePos) void {
        if (self.idx == 0) return;
        var last_newline_idx: u32 = 0;
        var line_num: u32 = 1;
        var i: u32 = 0;
        while (i <= self.idx) : (i += 1) {
            if (self.set.buf[i] != '\n') continue;
            last_newline_idx = i;
            line_num += 1;
        }
        self.line = line_num;
        self.col = if (line_num == 1) self.idx + 1 else self.idx - last_newline_idx;
    }
    pub fn getLine(self: *filePos) []const u8 {
        var start_idx = self.idx;
        while (self.set.buf[start_idx] != '\n' and start_idx > 0) : (start_idx -= 1) {}
        if (start_idx != 0) start_idx += 1;
        var end_idx = self.idx;
        while (self.set.buf[end_idx] != '\n' and end_idx < self.set.buf.len) : (end_idx += 1) {}
        return self.set.buf[start_idx..end_idx];
    }
};

pub fn reportErr(writer: std.fs.File.Writer, comptime err: SyntaxErr, set: *parse.Set, idx: u32) anyerror {
    var pos = filePos{ .set = set, .idx = idx };
    pos.computeCoords();

    try writer.print("{s}:{d}:{d}: error: ", .{ pos.set.filepath, pos.line, pos.col });

    switch (err) {
        SyntaxErr.AssignmentToNothing => {
            _ = try writer.write("assignment to nothing");
        },
        SyntaxErr.ExprIsTypeName => {
            _ = try writer.write("type names are not expressions");
        },
        SyntaxErr.InvalidSyntax => {
            _ = try writer.write("invalid syntax");
        },
        SyntaxErr.InvalidTypeSpecifier => {
            _ = try writer.write("invalid type specifier: not one of 'bool', 'date', 'num', 'str'");
        },
        SyntaxErr.MisplacedNode => {
            try writer.print("expected ';' or '{c}' before node declaration", .{'{'});
        },
        SyntaxErr.NameIsKeyword => {
            _ = try writer.write("cannot use keyword as name");
        },
        SyntaxErr.NoExpr => {
            _ = try writer.write("expected expression after '='");
        },
        SyntaxErr.NoExprName => {
            _ = try writer.write("expected expression name before type specifier");
        },
        SyntaxErr.NoLeftParen => {
            _ = try writer.write("')' does not match any '('");
        },
        SyntaxErr.NoNodeName => {
            _ = try writer.write("expected node name after initialiser");
        },
        SyntaxErr.NoRightCurly => {
            try writer.print("expected '{c}' to terminate node body", .{'}'});
        },
        SyntaxErr.NoSemicolonAfterBody => {
            _ = try writer.write("expected ';' to end node (expressions disallowed after body end)");
        },
        SyntaxErr.NoSemicolonAfterNode => {
            _ = try writer.write("expected ';' to end previous node");
        },
        SyntaxErr.NoTypeAfterColon => {
            _ = try writer.write("expected type: one of 'bool', 'date', 'num', 'str'");
        },
        SyntaxErr.StrNoClosingQuote => {
            _ = try writer.write("expected quote to close previous string");
        },
        SyntaxErr.Unimplemented => {
            _ = try writer.write("unimplemented");
        },
    }

    try writer.print("\n\t{s}\n\t", .{pos.getLine()});
    for (1..pos.col) |_| try writer.writeByte(' ');
    _ = try writer.write("^\n");

    return err;
}
