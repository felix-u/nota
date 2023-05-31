const std = @import("std");
const log = @import("log.zig");

pub const reserved_words = .{
    "true",
    "false",
    "bool",
    "date",
    "num",
    "str",
};

pub fn ensureNotKeyword(
    str: []const u8,
    loc: log.filePosition,
    errorWriter: std.fs.File.Writer,
) !void {
    inline for (reserved_words) |keyword| {
        if (std.mem.eql(u8, str, keyword)) {
            return log.reportError(log.SyntaxError.NameIsKeyword, loc, errorWriter);
        }
    }
}
