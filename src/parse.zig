const ast = @import("ast.zig");
const log = @import("log.zig");
const std = @import("std");
const token = @import("token.zig");

pub const types = [_][]const u8{
    "bool",
    "date",
    "num",
    "str",
};

pub const bool_values = [_][]const u8{
    "true",
    "false",
};

pub const reserved_all = types ++ bool_values;

pub fn ensureNotKeyword(
    err_writer: std.fs.File.Writer,
    comptime reserved_list: []const []const u8,
    comptime err: log.SyntaxErr,
    set: *Set,
    str_beg: u32,
    str_end: u32,
) !void {
    inline for (reserved_list) |keyword| {
        if (std.mem.eql(u8, set.buf[str_beg..str_end], keyword)) {
            return log.reportErr(err_writer, err, set, str_beg);
        }
    }
}

pub fn isValidSymbolChar(c: u21) bool {
    return switch (c) {
        '_', '.', '-' => true,
        else => !(c < '0' or
            (c > '9' and c < 'A') or
            (c > 'Z' and c < 'a') or
            (c > 'z' and c < 128)),
    };
}

pub const Set = struct {
    allocator: std.mem.Allocator,
    filepath: []const u8,
    buf: []const u8,
    buf_it: std.unicode.Utf8Iterator,
    toks: std.MultiArrayList(token.Token),
    tok_it: ast.TokenIterator,
    node_map: ast.NodeMap,
    nodes: std.MultiArrayList(ast.Node),
    decls: std.MultiArrayList(ast.Decl),
    exprs: std.MultiArrayList(ast.Expr),

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        filepath: []const u8,
        buf: []const u8,
    ) !*Self {
        var toks: std.MultiArrayList(token.Token) = .{};

        var self = Self{
            .allocator = allocator,
            .filepath = filepath,
            .buf = buf,
            .buf_it = (try std.unicode.Utf8View.init(buf)).iterator(),
            .toks = toks,
            .tok_it = .{ .toks = &toks },
            .node_map = ast.NodeMap.init(allocator),
            .nodes = .{},
            .decls = .{},
            .exprs = .{},
        };

        return &self;
    }
};
