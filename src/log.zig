const std = @import("std");
const parse = @import("parse.zig");

pub const SyntaxError = error{
    AssignmentToNothing,
    ExprIsTypeName,
    InvalidSyntax,
    InvalidTypeSpecifier,
    MisplacedNode,
    NameIsKeyword,
    NoExpr,
    NoExprName,
    NoNodeName,
    NoSemicolonAfterBody,
    NoSemicolonAfterNode,
    NoTypeAfterColon,
    StrNoClosingQuote,
    Unimplemented,
};

pub const filePosition = struct {
    set: *parse.Set = undefined,
    idx: u32 = 0,
    line: u32 = 1,
    col: u32 = 1,

    pub fn computeCoords(self: *filePosition) void {
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
    pub fn getLine(self: *filePosition) []const u8 {
        var start_idx = self.idx;
        while (self.set.buf[start_idx] != '\n' and start_idx > 0) : (start_idx -= 1) {}
        if (start_idx != 0) start_idx += 1;
        var end_idx = self.idx;
        while (self.set.buf[end_idx] != '\n' and end_idx < self.set.buf.len) : (end_idx += 1) {}
        return self.set.buf[start_idx..end_idx];
    }
};

pub fn reportError(writer: std.fs.File.Writer, comptime err: SyntaxError, set: *parse.Set, idx: u32) anyerror {
    var pos = filePosition{ .set = set, .idx = idx };
    pos.computeCoords();

    try writer.print("{s}:{d}:{d}: error: ", .{ pos.set.filepath, pos.line, pos.col });

    switch (err) {
        SyntaxError.AssignmentToNothing => {
            try writer.print("assignment to nothing", .{});
        },
        SyntaxError.ExprIsTypeName => {
            try writer.print("type names are not expressions", .{});
        },
        SyntaxError.InvalidSyntax => {
            try writer.print("invalid syntax", .{});
        },
        SyntaxError.InvalidTypeSpecifier => {
            try writer.print("invalid type specifier: not one of 'bool', 'date', 'num', 'str'", .{});
        },
        SyntaxError.MisplacedNode => {
            try writer.print("expected ';' or '{c}' before node declaration", .{'{'});
        },
        SyntaxError.NameIsKeyword => {
            try writer.print("cannot use keyword as name", .{});
        },
        SyntaxError.NoExpr => {
            try writer.print("expected expression after '='", .{});
        },
        SyntaxError.NoExprName => {
            try writer.print("expected expression name before type specifier", .{});
        },
        SyntaxError.NoNodeName => {
            try writer.print("expected node name after initialiser", .{});
        },
        SyntaxError.NoSemicolonAfterBody => {
            try writer.print("expected ';' to end node (expressions disallowed after body end)", .{});
        },
        SyntaxError.NoSemicolonAfterNode => {
            try writer.print("expected ';' to end previous node", .{});
        },
        SyntaxError.NoTypeAfterColon => {
            try writer.print("expected type: one of 'bool', 'date', 'num', 'str'" ++
                "(type inference uses '=', not ':=')", .{});
        },
        SyntaxError.StrNoClosingQuote => {
            try writer.print("expected quote to close previous string", .{});
        },
        SyntaxError.Unimplemented => {
            try writer.print("unimplemented", .{});
        },
    }

    try writer.print("\n\t{s}\n\t", .{pos.getLine()});
    for (1..pos.col) |_| try writer.print(" ", .{});
    try writer.print("^\n", .{});

    return err;
}
