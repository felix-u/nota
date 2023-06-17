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

pub const Set = struct {
    filepath: []const u8 = undefined,
    buf: []const u8 = undefined,
    buf_it: token.BufIterator = .{},
    token_list: token.TokenList = .{},
    node_list: ast.NodeList = .{},
    expr_list: ast.ExprList = .{},
};
