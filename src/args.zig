const std = @import("std");

pub const Kind = enum(u8) {
    boolean_optional = 0,
    boolean_required = 1,
    single_positional_optional = 2,
    single_positional_required = 3,
    multi_positional_optional = 4,
    multi_positional_required = 5,

    pub fn isRequired(comptime self: *@This()) bool {
        return @enumToInt(self) % 2 == 1;
    }
};

pub const Flag = struct {
    short_form: ?u8 = null,
    long_form: []const u8,
    kind: Kind = .boolean_optional,
};

pub const Command = struct {
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    flags: ?[]const Flag = null,
    kind: Kind = .boolean_optional,
};

pub const help_flag = Flag{
    .short_form = 'h',
    .long_form = "help",
};
pub const version_flag = Flag{
    .long_form = "version",
};

pub const ParseParams = struct {
    commands: []const Command = &.{.{}},
    description: ?[]const u8 = null,
    version: ?[]const u8 = null,
};

pub fn parse(
    allocator: std.mem.Allocator,
    writer: std.fs.File.Writer,
    argv: [][]const u8,
    comptime p: ParseParams,
) !void {
    _ = allocator;
    if (argv.len == 1) {
        try printHelp(writer, argv[0], p);
        return;
    }
}

pub fn printHelp(
    writer: std.fs.File.Writer,
    name: []const u8,
    comptime p: ParseParams,
) !void {
    try writer.print("{s}", .{name});
    if (p.description) |desc| try writer.print(" - {s}", .{desc});
    if (p.version) |ver| try writer.print(" (version {s})", .{ver});
    try writer.print("\n", .{});
}
