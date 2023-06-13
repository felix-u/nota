const std = @import("std");

pub const Error = error{
    Help,
    InvalidArgument,
    InvalidFlag,
    MissingArgument,
    MissingFlag,
};

pub const Kind = enum(u8) {
    help = 0,
    version = 2,
    boolean_optional = 4,
    boolean_required = 5,
    single_positional_optional = 6,
    single_positional_required = 7,
    multi_positional_optional = 8,
    multi_positional_required = 9,

    pub fn isRequired(comptime self: *const @This()) bool {
        return @enumToInt(self.*) % 2 == 1;
    }
};

pub const Flag = struct {
    short_form: ?u8 = null,
    long_form: []const u8,
    description: []const u8,
    kind: Kind = .boolean_optional,
    positional_type: ?[]const u8 = null,

    fn resultType(comptime self: *const @This()) type {
        if (@enumToInt(self.kind) <= @enumToInt(Kind.single_positional_required)) return bool;

        comptime var field_type = ?u8;
        if (self.kind == .multi_positional_optional or self.kind == .multi_positional_required) {
            field_type = ?[]const []const u8;
        }

        return @Type(.{ .Struct = .{
            .layout = .Auto,
            .fields = .{
                .name = "received",
                .type = field_type,
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            },
            .decls = &.{},
            .is_tuple = false,
        } });
    }
};

pub const Command = struct {
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    kind: Kind = .boolean_optional,
    flags: ?[]const Flag = null,

    fn resultType(comptime self: *const @This()) type {
        if (self.flags == null) return void;
        comptime var fields: [self.flags.?.len]std.builtin.Type.StructField = undefined;
        inline for (&fields, self.flags.?) |*field, flag| {
            field.* = .{
                .name = flag.long_form,
                .type = ?flag.resultType(),
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            };
        }
        return @Type(.{ .Struct = .{
            .layout = .Auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        } });
    }

    fn listResultType(comptime cmds: []const @This()) type {
        if (cmds.len == 0) return void;
        comptime var fields: [cmds.len]std.builtin.Type.StructField = undefined;
        inline for (&fields, cmds) |*field, cmd| {
            field.* = .{
                .name = cmd.name orelse "no_command",
                .type = ?cmd.resultType(),
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            };
        }
        return @Type(.{ .Struct = .{
            .layout = .Auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        } });
    }
};

pub const help_flag = Flag{
    .short_form = 'h',
    .long_form = "help",
    .description = "Print this help and exit",
    .kind = .help,
};
pub const version_flag = Flag{
    .long_form = "version",
    .description = "Print version information and exit",
    .kind = .version,
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
) !Command.listResultType(p.commands) {
    _ = allocator;

    const Result = Command.listResultType(p.commands);
    var result: Result = undefined;
    inline for (@typeInfo(Result).Struct.fields) |field| {
        @field(result, field.name) = null;
    }

    // Error case: `commands` is an empty slice.
    if (p.commands.len == 0) @compileError("at least one command must be provided");

    // Error case: a command with .name = null is the root command - the binary itself, with no subcommands.
    // There cannot be other commands.
    if (p.commands.len > 1) {
        inline for (p.commands) |cmd| {
            if (cmd.name == null or cmd.description == null) {
                @compileError("a command with .name = null or .description = null indicates an" ++
                    " absence of subcommands and must be the only command");
            }
        }
    }

    // Error case: there is 1 command only, and it is named. Why? This should be the root command, with .name = null.
    if (p.commands.len == 1 and p.commands[0].name != null) {
        @compileError("a named command implies the existence of several others, but there is only 1;\n" ++
            "leave .name = null");
    }

    // Error case: the root command has a description. The `description` passed to parse() should be used instead.
    if (p.commands[0].name == null and p.commands[0].description != null) {
        @compileError("the root command takes no description; " ++
            "use ParseParams.description instead and leave command.description = null");
    }

    // Error case: duplicate command name.
    if (p.commands.len > 1) {
        comptime var last_cmd_name: ?[]const u8 = null;
        inline for (p.commands) |cmd| {
            if (last_cmd_name != null and comptime std.mem.eql(u8, cmd.name.?, last_cmd_name.?)) {
                const err = std.fmt.comptimePrint("{s} = {s}\n^two commands cannot have identical names", .{ cmd.name.?, last_cmd_name.? });
                @compileError(err);
            }
            last_cmd_name = cmd.name;
        }
    }

    // Error case: duplicate flag name (under same command).
    inline for (p.commands) |cmd| {
        if (cmd.flags != null) {
            comptime var last_flag_long: ?[]const u8 = null;
            comptime var last_flag_short: ?u8 = null;
            inline for (cmd.flags.?) |flag| {
                if (last_flag_long != null and comptime std.mem.eql(u8, flag.long_form, last_flag_long.?)) {
                    @compileError("two flags of the same command cannot have identical long forms");
                }
                if (last_flag_short != null and flag.short_form != null and last_flag_short.? == flag.short_form.?) {
                    @compileError("two flags of the same command cannot have identical short forms");
                }
                last_flag_long = flag.long_form;
                last_flag_short = flag.short_form;
            }
        }
    }

    // Runtime

    const add_flags = if (p.version != null) .{ help_flag, version_flag } else .{help_flag};
    const general_flags = if (p.commands.len > 1) add_flags else (p.commands[0].flags orelse .{}) ++ add_flags;
    _ = general_flags;

    // for (p.commands) |cmd| {
    // }

    // for (argv) |arg| {
    //     var arg_kind: enum { positional, short_flag, long_flag } = .positional;
    //     if (arg.len == 1) continue;
    //     if (arg[0] == '-' and arg[1] != '-') {
    //         arg_kind = .short_flag;
    //         for (arg[1..]) |c| {
    //         }
    //     }
    //     else if (arg[0] == '-' and arg[1] == '-') {
    //         arg_kind = .long_flag;
    //     }
    // }

    // Case: binary expected arguments but got none.
    if (p.commands.len == 1 and @enumToInt(p.commands[0].kind) > @enumToInt(Kind.boolean_required) and argv.len == 1) {
        try printHelp(writer, argv[0], p);
        return Error.MissingArgument;
    }

    try writer.print("{}\n", .{result});
    return result;
}

const indent = "  ";
const indent_required = "* ";

pub fn printHelp(
    writer: std.fs.File.Writer,
    name: []const u8,
    comptime p: ParseParams,
) !void {
    try writer.print("{s}", .{name});
    if (p.description) |desc| try writer.print(" - {s}", .{desc});
    if (p.version) |ver| try writer.print(" (version {s})", .{ver});
    try writer.print("\n", .{});

    try writer.print("\nUSAGE:\n{s}{s}", .{ indent, name });
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
    if (max_flag_num > 0) try writer.print(" {c}option{c}", .{ brackets[0], brackets[1] });
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

    if (p.commands.len == 1 and p.commands[0].flags != null) {
        try writer.print("\nOPTIONS:\n", .{});
        const all_flags = p.commands[0].flags.? ++ (if (p.version != null) .{ help_flag, version_flag } else .{help_flag});
        inline for (all_flags) |flag| {
            try printFlag(writer, flag);
        }
    } else {
        try writer.print("\nCOMMANDS:\n", .{});
        inline for (p.commands) |cmd| {
            if (cmd.name != null) try writer.print("{s}{s}\t\t{s}\n", .{ indent, cmd.name.?, cmd.description.? });
        }
        try writer.print("\nGENERAL OPTIONS:\n", .{});
        try printFlag(writer, help_flag);
        if (p.version != null) try printFlag(writer, version_flag);
    }
}

pub fn printFlag(writer: std.fs.File.Writer, comptime flag: Flag) !void {
    const indent_str = if (comptime flag.kind.isRequired()) indent_required else indent;
    try writer.print("{s}", .{indent_str});

    if (flag.short_form) |char| {
        try writer.print("-{c}, ", .{char});
    } else try writer.print("    ", .{});

    try writer.print("--{s}", .{flag.long_form});

    if (@enumToInt(flag.kind) > @enumToInt(Kind.boolean_required)) {
        const pos_type = if (flag.positional_type != null) flag.positional_type.? else "arg";
        const maybe_ellipses = if (@enumToInt(flag.kind) > @enumToInt(Kind.single_positional_required)) "..." else "";
        try writer.print(" <{s}>{s}", .{ pos_type, maybe_ellipses });
    }

    try writer.print("\n", .{});

    try writer.print("\t{s}\n", .{flag.description});
}
