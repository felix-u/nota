const ast = @import("ast.zig");
const log = @import("log.zig");
const std = @import("std");
const token = @import("token.zig");

pub fn keyword(str: []const u8) token.Kind {
    const kind = std.meta.stringToEnum(token.Kind, str);
    if (kind != .true and kind != .false and
        (kind == null or
        @intFromEnum(kind.?) <= @intFromEnum(token.Kind.keyword_beg)))
    {
        return .none;
    }
    return kind.?;
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

pub const Context = struct {
    allocator: std.mem.Allocator,
    writer: std.fs.File.Writer,
    err_writer: std.fs.File.Writer,
    filepath: []const u8,
    buf: []const u8,
    buf_it: std.unicode.Utf8Iterator = undefined,
    toks: std.MultiArrayList(token.Token) = undefined,
    tok_it: ast.TokenIterator = undefined,
    nodes: ast.NodeList = undefined,
    childs: ast.Childs = undefined,

    const Self = @This();

    pub fn init(self: *Self) !void {
        self.buf_it = (try std.unicode.Utf8View.init(self.buf)).iterator();
        self.tok_it = .{ .toks = &self.toks, .i = 0 };
        self.childs = ast.Childs.init(self.allocator);

        try self.nodes.append(self.allocator, .{});

        try self.childs.append(
            try std.ArrayList(u32).initCapacity(self.allocator, 1),
        );
    }

    pub fn initParse(self: *Self) !void {
        try init(self);
        try token.parseToksFromBuf(self);
        try ast.parseTreeFromToks(self);
    }
};
