const ast = @import("ast.zig");
const log = @import("log.zig");
const print = @import("print.zig");
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

pub const Context = struct {
    allocator: std.mem.Allocator,
    writer: std.fs.File.Writer,
    err_writer: std.fs.File.Writer,
    filepath: []const u8 = undefined,
    buf: []const u8 = undefined,
    buf_it: std.unicode.Utf8Iterator = undefined,
    toks: std.MultiArrayList(token.Token) = undefined,
    tok_it: ast.TokenIterator = undefined,
    err_char: u8 = 0,
    nodes: ast.NodeList = .{},
    childs: ast.Childs = undefined,
    childs_i: u32 = 0,

    pub fn init(self: *@This()) !void {
        self.buf_it = (try std.unicode.Utf8View.init(self.buf)).iterator();
        self.tok_it = .{ .ctx = self, .i = 0 };
        self.childs = ast.Childs.init(self.allocator);

        try self.nodes.append(self.allocator, .{});

        try self.childs.append(
            try std.ArrayList(u32).initCapacity(self.allocator, 1),
        );
    }

    pub fn initFromPath(self: *@This(), path: []const u8) !void {
        const filebuf = try readFileAlloc(self.allocator, path);

        self.filepath = path;
        self.buf = filebuf;

        try self.init();
    }

    pub fn parse(self: *@This()) !void {
        try token.parseToksFromBuf(self);
        try ast.parseTreeFromToks(self);
    }

    pub fn parseAndPrint(
        self: *@This(),
        comptime mode: enum(u8) { pretty, debug },
        use_ansi_clr: bool,
    ) !void {
        const writer = self.writer;

        switch (mode) {
            inline .pretty => {
                try token.parseToksFromBuf(self);
                try ast.parseTreeFromToks(self);
                if (use_ansi_clr) {
                    try print.prettyAst(.ansi_clr_enabled, self);
                } else try print.prettyAst(.ansi_clr_disabled, self);
            },
            inline .debug => {
                _ = try writer.write("Begin tokenising... ");
                try token.parseToksFromBuf(self);
                _ = try writer.write("Done!\n");
                try print.toks(self);

                _ = try writer.write("\nBegin AST parsing... ");
                try ast.parseTreeFromToks(self);
                _ = try writer.write("Done!\n");
                try print.debugAst(self);
            },
        }
    }

    pub inline fn lexeme(self: *const @This(), tok_i: u32) []const u8 {
        const beg = self.toks.items(.beg_i)[tok_i];
        const end = self.toks.items(.end_i)[tok_i];
        return self.buf[beg..end];
    }

    pub fn err(
        self: *@This(),
        comptime fmt: []const u8,
        args: anytype,
    ) anyerror {
        try self.err_writer.print("error: " ++ fmt ++ "\n", args);
        return log.err(self, log.Err.None, self.tok_it.i);
    }
};

pub fn readFileAlloc(
    allocator: std.mem.Allocator,
    filepath: []const u8,
) ![]const u8 {
    const cwd = std.fs.cwd();

    const infile = try cwd.openFile(filepath, .{ .mode = .read_only });
    defer infile.close();

    return try infile.readToEndAlloc(allocator, std.math.maxInt(u32));
}
