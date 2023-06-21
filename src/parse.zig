const std = @import("std");
const ascii = std.ascii;
const ast = @import("ast.zig");
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
    errorWriter: std.fs.File.Writer,
    comptime reserved_list: []const []const u8,
    comptime err: log.SyntaxError,
    set: *Set,
    str_start: u32,
    str_end: u32,
) !void {
    inline for (reserved_list) |keyword| {
        if (std.mem.eql(u8, set.buf[str_start..str_end], keyword)) {
            return log.reportError(errorWriter, err, set, str_start);
        }
    }
}

pub const Set = struct {
    filepath: []const u8 = undefined,
    buf: []const u8 = undefined,
    buf_it: token.BufIterator = .{},
    token_list: token.TokenList = .{},
    node_list: ast.NodeList = .{},
    expr_list: ast.ExprList = .{},
};
