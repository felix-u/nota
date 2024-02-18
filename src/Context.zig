const ast = @import("ast.zig");
const print = @import("print.zig");
const std = @import("std");
const token = @import("token.zig");

allocator: std.mem.Allocator,
writer: std.fs.File.Writer,
err_writer: std.fs.File.Writer,

filepath: []const u8 = undefined,
buf: []const u8 = undefined,
buf_it: std.unicode.Utf8Iterator = undefined,
toks: std.MultiArrayList(token.Token) = undefined,
tok_it: ast.TokenIterator = undefined,
// idents: std.StringHashMap(u32) = undefined,
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
    is_debug: bool,
    use_ansi_clr: bool,
) !void {
    if (is_debug) {
        try token.parseToksFromBuf(self);
        try print.toks(self);
        try ast.parseTreeFromToks(self, .{});
        try print.debugAst(self);
    } else {
        try token.parseToksFromBuf(self);
        try ast.parseTreeFromToks(self, .{});
        try print.prettyAst(use_ansi_clr, self);
    }
}

pub fn lexeme(self: *const @This(), tok_i: u32) []const u8 {
    const kind = self.toks.items(.kind)[tok_i];
    switch (kind) {
        '\n' => return "\\n",
        else => {
            const beg = self.toks.items(.beg_i)[tok_i];
            const end = self.toks.items(.end_i)[tok_i];
            return self.buf[beg..end];
        },
    }
}

pub const FilePos = struct {
    row: u32,
    row_beg_i: u32,
    row_end_i: u32,
    col: u32,
};

pub fn filePosFromIndex(self: @This(), index: u32) FilePos {
    var pos = FilePos{
        .row = 1,
        .row_beg_i = 0,
        .row_end_i = 0,
        .col = 0,
    };

    var i: u32 = 0;
    while (i < index) : (i += 1) {
        if (self.buf[i] == '\n') {
            pos.row += 1;
            pos.row_beg_i = i + 1;
            pos.col = 0;
            continue;
        }
        pos.col += 1;
    }

    pos.row_end_i = i;
    while (pos.row_end_i < self.buf.len and self.buf[pos.row_end_i] != '\n') {
        pos.row_end_i += 1;
    }

    return pos;
}

pub fn err(self: *@This(), comptime fmt: []const u8, args: anytype) anyerror {
    const writer = self.err_writer;

    const beg_i = if (self.toks.items(.kind)[self.tok_it.i] ==
        @intFromEnum(token.Kind.eof))
        self.toks.items(.beg_i)[self.tok_it.i]
    else
        self.toks.items(.beg_i)[self.tok_it.i] + 1;

    const pos = self.filePosFromIndex(@intCast(beg_i));

    try writer.print("{s}:{d}:{d}: ", .{ self.filepath, pos.row, pos.col });
    try writer.print("error: " ++ fmt ++ "\n", args);

    try writer.print("{s}\n", .{self.buf[pos.row_beg_i..pos.row_end_i]});
    for (pos.row_beg_i + 1..beg_i) |_| try writer.writeByte(' ');
    try writer.writeByte('^');

    const end_i = self.toks.items(.end_i)[self.tok_it.i];
    for (beg_i..end_i) |_| try writer.writeByte('~');

    try writer.writeByte('\n');
    return error{ParseError}.ParseError;
}

pub fn readFileAlloc(
    allocator: std.mem.Allocator,
    filepath: []const u8,
) ![]const u8 {
    const cwd = std.fs.cwd();
    const infile = try cwd.openFile(filepath, .{ .mode = .read_only });
    defer infile.close();
    return try infile.readToEndAlloc(allocator, std.math.maxInt(u32));
}
