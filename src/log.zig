const std = @import("std");

pub const SyntaxError = error{
    InvalidTypeSpecifier,
    MisplacedNode,
    NoNodeName,
    NoSemicolonAfterBody,
    NoSemicolonAfterNode,
    StrNoClosingQuote,
    Unimplemented,
};

pub const filePosition = struct {
    filepath: []const u8 = undefined,
    buf: []const u8 = undefined,
    idx: u32 = 0,
    line: u32 = 1,
    col: u32 = 1,

    pub fn computeCoords(self: *filePosition) void {
        if (self.idx == 0) return;
        var last_newline_idx: u32 = 0;
        var line_num: u32 = 1;
        var i: u32 = 0;
        while (i <= self.idx) : (i += 1) {
            if (self.buf[i] != '\n') continue;
            last_newline_idx = i;
            line_num += 1;
        }
        self.line = line_num;
        self.col = if (line_num == 1) self.idx + 1 else self.idx - last_newline_idx;
    }
    pub fn getLine(self: *filePosition) []const u8 {
        var start_idx = self.idx;
        while (self.buf[start_idx] != '\n' and start_idx > 0) : (start_idx -= 1) {}
        if (start_idx != 0) start_idx += 1;
        var end_idx = self.idx;
        while (self.buf[end_idx] != '\n' and end_idx < self.buf.len) : (end_idx += 1) {}
        return self.buf[start_idx..end_idx];
    }
};

pub fn reportError(comptime err: SyntaxError, file_pos: filePosition, errorWriter: std.fs.File.Writer) anyerror {
    var pos = file_pos;
    try errorWriter.print("{s}:{d}:{d}: error: ", .{ pos.filepath, pos.line, pos.col });
    switch (err) {
        SyntaxError.InvalidTypeSpecifier => {
            try errorWriter.print("invalid type specifier", .{});
        },
        SyntaxError.MisplacedNode => {
            try errorWriter.print("expected ';' or '{c}' before node declaration", .{'{'});
        },
        SyntaxError.NoNodeName => {
            try errorWriter.print("expected node name after initialiser", .{});
        },
        SyntaxError.NoSemicolonAfterBody => {
            try errorWriter.print("expected ';' to end node (expressions disallowed after body end)", .{});
        },
        SyntaxError.NoSemicolonAfterNode => {
            try errorWriter.print("expected ';' to end previous node", .{});
        },
        SyntaxError.StrNoClosingQuote => {
            try errorWriter.print("expected quote to close previous string", .{});
        },
        SyntaxError.Unimplemented => {
            try errorWriter.print("unimplemented", .{});
        },
    }
    try errorWriter.print("\n\t{s}\n\t", .{pos.getLine()});
    for (1..pos.col) |_| try errorWriter.print(" ", .{});
    try errorWriter.print("^\n", .{});
    return err;
}
