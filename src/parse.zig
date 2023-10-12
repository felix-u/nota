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
    filepath: []const u8,
    buf: []const u8,
    buf_it: std.unicode.Utf8Iterator,
    toks: std.MultiArrayList(token.Token),
    tok_it: ast.TokenIterator,
    nodes: ast.NodeList,
    childs: ast.Childs,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        filepath: []const u8,
        buf: []const u8,
    ) !*Self {
        const self = try allocator.create(Self);

        self.* = .{
            .allocator = allocator,
            .filepath = filepath,
            .buf = buf,
            .buf_it = (try std.unicode.Utf8View.init(buf)).iterator(),
            .toks = .{},
            .tok_it = .{ .toks = &self.toks, .i = 0 },
            .nodes = .{},
            .childs = ast.Childs.init(allocator),
        };

        try self.nodes.append(allocator, .{});

        try self.childs.append(
            try std.ArrayList(u32).initCapacity(self.allocator, 1),
        );

        return self;
    }
};
