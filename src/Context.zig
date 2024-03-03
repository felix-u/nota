const print = @import("print.zig");
const std = @import("std");
const Token = @import("Token.zig");

allocator: std.mem.Allocator,
writer: std.fs.File.Writer,
err_writer: std.fs.File.Writer,

filepath: []const u8 = undefined,
buf: []const u8 = undefined,
buf_it: std.unicode.Utf8Iterator = undefined,
toks: std.ArrayList(Token) = undefined,

pub fn init(self: *@This()) !void {
    self.buf_it = (try std.unicode.Utf8View.init(self.buf)).iterator();
}

pub fn initFromPath(self: *@This(), path: []const u8) !void {
    const filebuf = try readFileAlloc(self.allocator, path);
    self.filepath = path;
    self.buf = filebuf;
    try self.init();
}

pub fn parse(self: *@This()) !void {
    try Token.lexBytes(self);
}

pub fn parseAndPrint(
    self: *@This(),
    is_debug: bool,
    use_ansi_clr: bool,
) !void {
    _ = use_ansi_clr;
    try Token.lexBytes(self);
    if (is_debug) try print.toks(self);
}

pub fn lexeme(self: *const @This(), tok_i: u32) []const u8 {
    const tok = self.toks.items[tok_i];
    return self.buf[tok.beg_i..tok.end_i];
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
        @intFromEnum(Token.Kind.eof))
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
