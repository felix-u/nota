const std = @import("std");
const log = @import("log.zig");

pub const reserved_types = [_][]const u8{
    "bool",
    "date",
    "num",
    "str",
};

pub const reserved_values = [_][]const u8{
    "true",
    "false",
};

pub const reserved_all = reserved_types ++ reserved_values;

pub fn ensureNotKeyword(
    comptime reserved_list: []const []const u8,
    comptime err: log.SyntaxError,
    str: []const u8,
    loc: *log.filePosition,
    errorWriter: std.fs.File.Writer,
) !void {
    inline for (reserved_list) |keyword| {
        if (std.mem.eql(u8, str, keyword)) {
            loc.*.computeCoords();
            return log.reportError(err, loc.*, errorWriter);
        }
    }
}
