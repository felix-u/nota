const std = @import("std");

pub const Error = error{
    InvalidArgument,
    InvalidFlag,
    MissingArgument,
    MissingFlag,
    UnexpectedArgument,
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

    pub fn isRequired(comptime self: @This()) bool {
        return @enumToInt(self) % 2 == 1;
    }
};

pub const Flag = struct {
    short_form: ?u8 = null,
    long_form: []const u8,
    description: []const u8,
    kind: Kind = .boolean_optional,
    positional_type: ?[]const u8 = null,

    fn resultType(comptime self: *const @This()) type {
        return switch (self.kind) {
            inline .help, .version, .boolean_optional, .boolean_required => bool,
            inline .single_positional_optional, .single_positional_required => usize,
            inline .multi_positional_optional, .multi_positional_required => std.ArrayList(usize),
        };
    }
};

pub const Command = struct {
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    kind: Kind = .boolean_optional,
    flags: ?[]const Flag = null,

    fn resultType(comptime self: *const @This()) type {
        if (self.flags == null) return switch (self.kind) {
            inline .single_positional_optional, .single_positional_required => usize,
            inline .multi_positional_optional, .multi_positional_required => std.ArrayList(usize),
            inline else => bool,
        };
        comptime var fields: [self.flags.?.len + 1]std.builtin.Type.StructField = undefined;
        fields[0] = .{
            .name = "pos",
            .type = switch (self.kind) {
                inline .single_positional_optional, .single_positional_required => usize,
                inline .multi_positional_optional, .multi_positional_required => std.ArrayList(usize),
                inline else => bool,
            },
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };
        inline for (fields[1..], self.flags.?) |*field, flag| {
            field.* = .{
                .name = flag.long_form,
                .type = flag.resultType(),
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
                .type = if (cmd.name == null) cmd.resultType() else ?cmd.resultType(),
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

pub fn parseAlloc(
    allocator: std.mem.Allocator,
    writer: std.fs.File.Writer,
    argv: [][]const u8,
    comptime p: ParseParams,
) !?*Command.listResultType(p.commands) {

    // Initialise and pre-allocate.
    const Result = Command.listResultType(p.commands);
    var result = try allocator.create(Result);
    inline for (@typeInfo(Result).Struct.fields, 0..) |field, idx| {
        if (@enumToInt(p.commands[idx].kind) >= @enumToInt(Kind.multi_positional_optional)) {
            @field(result, field.name) = allocator.alloc(usize, argv.len);
        }
    }

    var arg_kind_list = try allocator.alloc(ArgKind, argv.len);
    defer allocator.free(arg_kind_list);

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

    // Error case: the root command is of optional kind, or .help or .version.
    if (p.commands.len == 1) {
        if (!comptime p.commands[0].kind.isRequired()) @compileError("the root command cannot be optional");
        if (p.commands[0].kind == .help or p.commands[0].kind == .version) {
            @compileError("the root command cannot have .kind = .help or .version, " ++
                " because the root command is not a help or version flag.");
        }
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

    if (p.commands.len == 1) {
        const cmd = p.commands[0];
        procArgKindList(&arg_kind_list, argv);
        var got_pos = false;
        cmd_arg: for (arg_kind_list[1..], 1..) |arg_kind, idx| {
            const arg = argv[idx];
            switch (arg_kind) {
                .command => unreachable,
                .positional => {
                    switch (cmd.kind) {
                        inline .boolean_required => return Error.UnexpectedArgument,
                        inline .single_positional_required => {
                            if (got_pos) return Error.UnexpectedArgument;
                            result.no_command.pos = idx;
                            got_pos = true;
                        },
                        inline .multi_positional_required => {
                            result.no_command.pos.appendAssumeCapacity(idx);
                            got_pos = true;
                        },
                        inline else => unreachable,
                    }
                },
                .positional_marker => continue :cmd_arg,
                .short_flag => {
                    match: for (arg[1..]) |short| {
                        if (short == help_flag.short_form) {
                            try printHelp(writer, argv[0], p);
                            return null;
                        }
                        if (cmd.flags) |flags| {
                            for (flags) |flag| {
                                if (flag.short_form) |flag_short| {
                                    if (short == flag_short) {
                                        break :match;
                                    }
                                }
                            }
                        }
                    } else return Error.InvalidFlag;
                },
                .long_flag => {
                    if (std.mem.eql(u8, arg[2..], help_flag.long_form)) {
                        try printHelp(writer, argv[0], p);
                        return null;
                    }
                    if (p.version != null and std.mem.eql(u8, arg[2..], version_flag.long_form)) {
                        try printVersion(writer, argv[0], p);
                        return null;
                    }
                    if (cmd.flags == null) return Error.InvalidFlag;
                    match: for (cmd.flags.?) |flag| {
                        if (std.mem.eql(u8, arg[2..], flag.long_form)) {
                            break :match;
                        }
                    } else return Error.InvalidFlag;
                },
            }
        }
    }

    // Case: binary expected arguments but got none.
    if (p.commands.len == 1 and @enumToInt(p.commands[0].kind) > @enumToInt(Kind.boolean_required) and argv.len == 1) {
        try printHelp(writer, argv[0], p);
        return Error.MissingArgument;
    }

    try writer.print("{}\n", .{result});
    return result;
}

const ArgKind = enum { command, positional, positional_marker, short_flag, long_flag };
fn procArgKindList(arg_kind_list: *[]ArgKind, argv: []const []const u8) void {
    var list = arg_kind_list.*;
    var only_positionals = false;
    var got_command = false;
    for (argv, 0..) |arg, idx| {
        if (only_positionals) {
            list[idx] = .positional;
        } else if (arg.len == 1) {
            if (got_command) {
                list[idx] = .command;
                got_command = true;
            } else list[idx] = .positional;
        } else if (arg[0] == '-' and arg[1] != '-') {
            list[idx] = .short_flag;
        } else if (arg.len == 2) {
            list[idx] = .positional_marker;
            only_positionals = true;
        } else if (arg[0] == '-' and arg[1] == '-') {
            list[idx] = .long_flag;
        } else if (got_command) {
            list[idx] = .command;
            got_command = true;
        } else list[idx] = .positional;
    }
    arg_kind_list.* = list;
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

pub fn printVersion(
    writer: std.fs.File.Writer,
    name: []const u8,
    comptime p: ParseParams,
) !void {
    if (p.version == null) return;
    try writer.print("{s}", .{name});
    try writer.print(" (version {s})", .{p.version.?});
    try writer.print("\n", .{});
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
