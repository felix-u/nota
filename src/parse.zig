const std = @import("std");
const ascii = std.ascii;
const log = @import("log.zig");
const token = @import("token.zig");

pub const types = [_][]const u8{
    "bool",
    "date",
    "num",
    "str",
};

pub const values = [_][]const u8{
    "true",
    "false",
};

pub const matches = [_][]const u8{
    "up",
    "down",
    "to",
    "through",
};

pub const reserved_all = types ++ values ++ matches;

pub fn ensureNotKeyword(
    errWriter: std.fs.File.Writer,
    comptime reserved_list: []const []const u8,
    comptime err: log.SyntaxErr,
    set: *Set,
    str_beg: u32,
    str_end: u32,
) !void {
    inline for (reserved_list) |keyword| {
        if (std.mem.eql(u8, set.buf[str_beg..str_end], keyword)) {
            return log.reportErr(errWriter, err, set, str_beg);
        }
    }
}

pub fn isValidSymbolChar(c: u21) bool {
    return switch (c) {
        '_', '.' => true,
        else => !(c < '0' or
            (c > '9' and c < 'A') or
            (c > 'Z' and c < 'a') or
            (c > 'z' and c < 128)),
    };
}

pub const Set = struct {
    filepath: []const u8 = undefined,
    buf: []const u8 = undefined,
    buf_it: std.unicode.Utf8Iterator = undefined,
    toks: token.TokenList = .{},
};
