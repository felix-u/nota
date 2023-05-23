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
};

pub fn reportError(file_pos: filePosition, errorWriter: std.fs.File.Writer) !void {
    _ = file_pos;
    _ = errorWriter;
}
