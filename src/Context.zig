const FilePosition = @import("FilePosition.zig");
const Instruction = @import("Instruction.zig");
const Interpret = @import("Interpret.zig");
const Procedure = @import("Procedure.zig");
const Token = @import("Token.zig");
const Stack = @import("Stack.zig");
const std = @import("std");

allocator: std.mem.Allocator,
writer: std.fs.File.Writer,
err_writer: std.fs.File.Writer,
filepath: []const u8 = undefined,
bytes: []const u8 = undefined,
bytes_it: std.unicode.Utf8Iterator = undefined,
toks: std.ArrayList(Token) = undefined,
tok_i: u32 = undefined,
instructions: Instruction.List = undefined,
instruction_stream: Instruction.List = undefined,
instruction_start_point: u32 = undefined,

stack: Stack = undefined,
jump_stack: std.ArrayList(u32) = undefined,
procedures_map: Procedure.Map = undefined,
procedures_list: Procedure.List = undefined,
procedures_total_instruction_count: u32 = undefined,

pub fn initFromFilepath(self: *@This(), filepath: []const u8) !void {
    const bytes = try readFileAlloc(self.allocator, filepath);
    self.filepath = filepath;
    self.bytes = bytes;
}

pub fn parse(self: *@This(), is_debug: bool, use_ansi_clr: bool) !void {
    _ = use_ansi_clr;
    try Token.lexBytes(self);
    if (is_debug) try Token.printAll(self);
    try Instruction.fromToks(self);
    if (is_debug) try Instruction.printAll(self);
    try Interpret.all(self);
}

pub fn lexeme(self: *const @This(), tok_i: u32) []const u8 {
    const tok = self.toks.items[tok_i];
    return self.bytes[tok.beg_i..tok.end_i];
}

pub fn err(self: *@This(), comptime fmt: []const u8, args: anytype) anyerror {
    const writer = self.err_writer;
    const tok = self.toks.items[self.tok_i];

    const beg_i: u32 = @intCast(tok.beg_i + 1);
    const pos = FilePosition.fromByteIndex(self.bytes, @intCast(tok.beg_i));

    try writer.print("{s}:{d}:{d}: ", .{ self.filepath, pos.row, pos.col });
    try writer.print("error: " ++ fmt ++ "\n", args);

    try writer.print("{s}\n", .{self.bytes[pos.row_beg_i..pos.row_end_i]});
    for (pos.row_beg_i + 1..beg_i) |_| try writer.writeByte(' ');
    try writer.writeByte('^');

    for (beg_i..tok.end_i) |_| try writer.writeByte('~');

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
