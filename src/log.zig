const std = @import("std");
const parse = @import("parse.zig");

pub const SyntaxErr = error{
    InvalidSyntax,
    NoClosingQuote,
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
        var end_i = self.idx;
        while (self.set.buf[end_i] != '\n' and end_i < self.set.buf.len) {
            end_i += 1;
        }

        var beg_i = if (self.idx == 0) 0 else self.idx - 1;
        while (self.set.buf[beg_i] != '\n' and beg_i - 1 > 0) {
            beg_i -= 1;
        }

        return self.set.buf[beg_i..end_i];
    }
};

pub fn reportErr(writer: std.fs.File.Writer, comptime err: SyntaxErr, set: *parse.Set, idx: u32) anyerror {
    var pos = filePos{ .set = set, .idx = idx };
    pos.computeCoords();

    try writer.print("{s}:{d}:{d}: error: ", .{ pos.set.filepath, pos.line, pos.col });

    switch (err) {
        SyntaxErr.InvalidSyntax => {
            _ = try writer.write("invalid syntax");
        },
        SyntaxErr.NoClosingQuote => {
            _ = try writer.write("expected quote to close string");
        },
    }

    try writer.print("{s}\n", .{pos.getLine()});

    var i: u32 = 1;
    while (i < pos.col) : (i += 1) {
        try writer.writeByte(' ');
    }
    _ = try writer.write("^\n");

    return err;
}
