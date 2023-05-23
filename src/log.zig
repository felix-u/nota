const std = @import("std");

pub const ParseError = error{
    NoNodeName,
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

pub fn reportError(comptime err: anyerror, file_pos: filePosition, errorWriter: std.fs.File.Writer) anyerror {
    var pos = file_pos;
    switch (err) {
        ParseError.NoNodeName => {
            try errorWriter.print("{s}:{d}:{d}: error: expected node name after initialiser\n", .{
                pos.filepath, pos.line, pos.col,
            });
            try errorWriter.print("\t{s}\n\t", .{pos.getLine()});
            for (0..pos.col) |_| try errorWriter.print(" ", .{});
            try errorWriter.print("^\n", .{});
        },
        else => {},
    }
    return err;
}
