const std = @import("std");

pub const Kind = enum(u8) {
    boolean_optional = 0,
    boolean_required = 1,
    single_positional_optional = 2,
    single_positional_required = 3,
    multi_positional_optional = 4,
    multi_positional_required = 5,

    pub fn isRequired(comptime self: *const @This()) bool {
        return @enumToInt(self.*) % 2 == 1;
    }
};

pub const Flag = struct {
    short_form: ?u8 = null,
    long_form: []const u8,
    kind: Kind = .boolean_optional,
    positional_type: ?[]const u8 = null,
};

pub const Command = struct {
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    kind: Kind = .boolean_optional,
    flags: ?[]const Flag = null,
};

pub const help_flag = Flag{
    .short_form = 'h',
    .long_form = "help",
};
pub const version_flag = Flag{
    .long_form = "version",
};

pub const ParseParams = struct {
    description: ?[]const u8 = null,
    version: ?[]const u8 = null,
    commands: []const Command = &.{.{}},
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
    // Error case: a command with .name = null is the root command - the binary itself, with no subcommands.
    // There cannot be other commands.
    if (p.commands.len > 1) {
        inline for (p.commands) |cmd| {
            if (cmd.name == null) @compileError("a command with .name = null indicates an absence of subcommands" ++
                " and must be the only command.");
        }
    }

    // Error case: there is 1 command only, and it is named. Why? This should be the root command, with .name = null.
    if (p.commands.len == 1 and p.commands[0].name != null) {
        @compileError("a named command implies the existence of several others, but there is only 1;\n" ++
            "leave .name = null.");
    }

    // Error case: the root command has a description. The `description` passed to parse() should be used instead.
    if (p.commands[0].name == null and p.commands[0].description != null) {
        @compileError("the root command takes no description; " ++
            "use ParseParams.description instead and leave command.description = null.");
    }

    try writer.print("{s}", .{name});
    if (p.description) |desc| try writer.print(" - {s}", .{desc});
    if (p.version) |ver| try writer.print(" (version {s})", .{ver});
    try writer.print("\n", .{});

    try writer.print("\nSYNOPSIS\n\t{s}", .{name});
    if (p.commands.len > 1) try writer.print(" <command>", .{});

    comptime var brackets = "[]";

    comptime var max_pos_cmd_requires = @enumToInt(Kind.boolean_required);
    inline for (p.commands) |cmd| {
        if (@enumToInt(cmd.kind) > max_pos_cmd_requires) max_pos_cmd_requires = @enumToInt(cmd.kind);
        if (comptime cmd.kind.isRequired()) brackets = "<>";
    }
    if (max_pos_cmd_requires > @enumToInt(Kind.boolean_required)) try writer.print(" {c}arg{c}", .{ brackets[0], brackets[1] });
    if (max_pos_cmd_requires > @enumToInt(Kind.single_positional_required)) try writer.print("...", .{});

    comptime var max_flag_num = 0;
    brackets = "[]";
    inline for (p.commands) |cmd| {
        if (cmd.flags) |flags| {
            if (flags.len > max_flag_num) max_flag_num = flags.len;
            inline for (flags) |flag| {
                if (comptime flag.kind.isRequired()) brackets = "<>";
            }
        }
    }
    if (max_flag_num > 0) try writer.print(" {c}flag{c}", .{ brackets[0], brackets[1] });
    if (max_flag_num > 1) try writer.print("...", .{});

    comptime var max_positional_expected = @enumToInt(Kind.boolean_required);
    inline for (p.commands) |cmd| {
        if (cmd.flags) |flags| {
            inline for (flags) |flag| {
                if (@enumToInt(flag.kind) > max_positional_expected) max_positional_expected = @enumToInt(flag.kind);
            }
        }
    }
    if (max_positional_expected > @enumToInt(Kind.boolean_required)) try writer.print(" {c}arg{c}", .{ brackets[0], brackets[1] });
    if (max_positional_expected > @enumToInt(Kind.single_positional_required)) try writer.print("...", .{});

    try writer.print("\n", .{});
}
