const std = @import("std");

pub const Error = error{
    InvalidArgument,
    InvalidCommand,
    InvalidFlag,
    MissingArgument,
    MissingFlag,
    UnexpectedArgument,
};

pub const Kind = enum(u8) {
    boolean,
    single_pos,
    multi_pos,
};

pub const Flag = struct {
    short: u8 = 0,
    long: []const u8 = "",

    kind: Kind = .boolean,
    required: bool = false,
    desc: []const u8 = "",
    usage: []const u8 = "",

    fn resultType(comptime self: *const @This()) type {
        return switch (self.kind) {
            inline .boolean => bool,
            inline .single_pos => if (self.required) usize else ?usize,
            inline .multi_pos => std.ArrayList(usize),
        };
    }
};

pub const Cmd = struct {
    kind: Kind = .boolean,
    desc: []const u8 = "",
    name: []const u8 = "",

    flags: []const Flag = &.{},

    fn resultType(comptime self: *const @This()) type {
        comptime var fields: [self.flags.len + 2]std.builtin.Type.StructField = undefined;
        fields[0] = .{
            .name = "invoked",
            .type = bool,
            .default_value = &false,
            .is_comptime = false,
            .alignment = 0,
        };

        fields[1] = .{
            .name = "pos",
            .type = switch (self.kind) {
                inline .boolean => bool,
                inline .single_pos => usize,
                inline .multi_pos => std.ArrayList(usize),
            },
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };

        inline for (fields[2..], self.flags) |*field, flag| {
            field.* = .{
                .name = flag.long,
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
                .name = cmd.name,
                .type = cmd.resultType(),
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
    .short = 'h',
    .long = "help",
    .desc = "Print this help and exit",
};

pub const ver_flag = Flag{
    .long = "version",
    .desc = "Print version information and exit",
};

pub const ParseParams = struct {
    desc: []const u8 = "",
    ver: []const u8 = "",
    usage: []const u8 = "",
    cmds: []const Cmd = &.{},
};

pub fn parseAlloc(
    allocator: std.mem.Allocator,
    writer: std.fs.File.Writer,
    argv: [][]const u8,
    comptime p: ParseParams,
) !?*Cmd.listResultType(p.cmds) {
    const Result = Cmd.listResultType(p.cmds);
    var result = try allocator.create(Result);
    errdefer allocator.destroy(result);

    inline for (@typeInfo(Result).Struct.fields, 0..) |_, i| {
        const cmd = p.cmds[i];

        if (cmd.kind == .multi_pos) {
            @field(result, cmd.name).pos = std.ArrayList(usize).init(allocator);
            try @field(result, cmd.name).pos.ensureTotalCapacity(argv.len);
        }

        inline for (cmd.flags) |flag| {
            if (flag.kind != .multi_pos) continue;
            @field(@field(result, cmd.name), flag.long) = std.ArrayList(usize).init(allocator);
            try @field(@field(result, cmd.name), flag.long).ensureTotalCapacity(argv.len);
        }
    }

    switch (p.cmds.len) {
        inline 0 => @compileError("at least one command must be provided"),
        inline 1 => if (p.cmds[0].name.len > 0 or p.cmds[0].desc.len > 0) {
            @compileError("a command with non-empty .name or .desc implies the existence of several others, \n" ++
                "but there is only 1; use ParseParams.desc");
        },
        inline else => {
            inline for (p.cmds) |cmd| {
                if (cmd.name.len > 0 and cmd.desc.len > 0) continue;
                @compileError("a command with empty .name or .desc indicates an" ++
                    " absence of subcommands and must be the only command");
            }
        },
    }

    var arg_kinds = try allocator.alloc(ArgKind, argv.len);
    defer allocator.free(arg_kinds);

    const add_flags = if (p.ver.len > 0) .{ help_flag, ver_flag } else .{help_flag};
    const general_flags = if (p.cmds.len > 1) add_flags else p.cmds[0].flags ++ add_flags;
    _ = general_flags;

    const to_proc = if (p.cmds.len == 1) argv else argv[1..];
    procArgKindList(arg_kinds, to_proc);
    std.debug.print("{any}\n", .{arg_kinds});

    @field(result, cmd.name).invoked = true;
    var got_pos = false;

    var arg_i: usize = if (p.cmds.len == 1) 1 else 2;
    cmd_arg: while (arg_i < argv.len) {
        const arg_kind = arg_kinds[arg_i];
        const arg = argv[arg_i];
        switch (arg_kind) {
            .cmd => unreachable,
            .pos => switch (cmd.kind) {
                inline .boolean => return Error.UnexpectedArgument,
                inline .single_pos => {
                    if (got_pos) return Error.UnexpectedArgument;
                    @field(result, cmd.name).pos = arg_i;
                    got_pos = true;
                },
                inline .multi_pos => {
                    @field(result, cmd.name).pos.appendAssumeCapacity(arg_i);
                    got_pos = true;
                },
            },
            .pos_marker => {},
            .short => for (arg[1..], 1..) |short, short_i| {
                if (short == help_flag.short) {
                    try printHelp(writer, argv[0], p);
                    return null;
                }

                if (cmd.flags.len == 0) return Error.InvalidFlag;

                match: inline for (cmd.flags) |flag| {
                    // Matched flag in short form.
                    if (flag.short != 0 and flag.short == short) {
                        switch (flag.kind) {
                            inline .boolean => {
                                @field(@field(result, cmd.name), flag.long) = true;
                            },
                            inline .single_pos => {
                                if (short_i != arg.len - 1 or
                                    arg_i == argv.len - 1 or
                                    arg_kinds[arg_i + 1] != .positional)
                                {
                                    return Error.MissingArgument;
                                }
                                arg_i += 1;
                                @field(@field(result, cmd.name), flag.long) = arg_i;
                                arg_i += 1;
                                continue :cmd_arg;
                            },
                            inline .multi_pos => {
                                if (short_i != arg.len - 1 or
                                    arg_i == argv.len - 1 or
                                    arg_kinds[arg_i + 1] != .positional)
                                {
                                    return Error.MissingArgument;
                                }
                                arg_i += 1;
                                while (arg_i < argv.len and arg_kinds[arg_i] == .positional) : (arg_i += 1) {
                                    @field(@field(result, cmd.name), flag.long).appendAssumeCapacity(arg_i);
                                } else continue :cmd_arg;
                            },
                        }
                        break :match;
                    }
                } else return Error.InvalidFlag;
            },
            .long => {
                if (std.mem.eql(u8, arg[2..], help_flag.long)) {
                    try printHelp(writer, argv[0], p);
                    return null;
                }
                if (p.ver.len > 0 and std.mem.eql(u8, arg[2..], ver_flag.long)) {
                    try printVer(writer, argv[0], p);
                    return null;
                }
                if (cmd.flags.len == 0) return Error.InvalidFlag;
                match: inline for (cmd.flags) |flag| {
                    if (std.mem.eql(u8, arg[2..], flag.long)) {
                        // Matched flag in long form.
                        switch (flag.kind) {
                            inline .boolean => {
                                @field(@field(result, cmd.name), flag.long) = true;
                            },
                            inline .single_pos => {
                                if (arg_i == argv.len - 1 or arg_kinds[arg_i + 1] != .positional) {
                                    return Error.MissingArgument;
                                }
                                arg_i += 1;
                                @field(@field(result, cmd.name), flag.long) = arg_i;
                                arg_i += 1;
                                continue :cmd_arg;
                            },
                            inline .multi_pos => {
                                if (arg_i == argv.len - 1 or arg_kinds[arg_i + 1] != .positional) {
                                    return Error.MissingArgument;
                                }
                                arg_i += 1;
                                while (arg_i < argv.len and arg_kinds[arg_i] == .positional) : (arg_i += 1) {
                                    @field(@field(result, cmd.name), flag.long).appendAssumeCapacity(arg_i);
                                } else continue :cmd_arg;
                            },
                        }
                        break :match;
                    }
                } else return Error.InvalidFlag;
                arg_i += 1;
                continue :cmd_arg;
            },
        }
        arg_i += 1;
        continue :cmd_arg;
    } // :cmd_arg

    if ((cmd.kind == .single_pos or cmd.kind == .multi_pos) and
        (!got_pos or argv.len == 1))
    {
        try printHelp(writer, argv[0], p);
        return Error.MissingArgument;
    }


    return result;
}

const ArgKind = enum { cmd, pos, pos_marker, short, long };
fn procArgKindList(arg_kinds: []ArgKind, argv: []const []const u8) void {
    var only_pos = false;
    var got_cmd = false;
    for (argv, 0..) |arg, i| {
        if (!got_cmd) {
            arg_kinds[i] = .cmd;
            got_cmd = true;
            continue;
        }

        if (only_pos) {
            arg_kinds[i] = .pos;
            continue;
        }

        arg_kinds[i] = switch (arg.len) {
            1 => .pos,
            else => blk: {
                if (std.mem.eql(u8, arg, "--")) break :blk .pos_marker;
                if (std.mem.startsWith(u8, arg, "--")) break :blk .long;
                if (arg[0] == '-') break :blk .short;
                break :blk .pos;
            },
        };
    }
}

const indent = "  ";
const indent_required = "* ";

pub fn printHelp(
    writer: std.fs.File.Writer,
    name: []const u8,
    comptime p: ParseParams,
) !void {
    _ = try writer.write(name);
    if (p.desc.len > 0) try writer.print(" - {s}", .{p.desc});
    if (p.ver.len > 0) try writer.print(" (version {s})", .{p.ver});
    try writer.writeByte('\n');

    if (p.usage.len > 0) try writer.print("\nUsage:\n{s}{s}\n", .{ indent, p.usage });

    if (p.cmds.len == 1 and p.cmds[0].flags.len > 0) {
        _ = try writer.write("\nOptions:\n");
        const all_flags = p.cmds[0].flags ++ (if (p.ver.len > 0) .{ help_flag, ver_flag } else .{help_flag});
        inline for (all_flags) |flag| {
            try printFlag(writer, flag);
        }
    } else {
        _ = try writer.write("\nCommands:\n");
        inline for (p.cmds) |cmd| {
            if (cmd.name.len > 0) try writer.print("{s}{s}\t\t{s}\n", .{ indent, cmd.name, cmd.desc });
        }
        _ = try writer.write("\nGeneral options:\n");
        try printFlag(writer, help_flag);
        if (p.ver.len > 0) try printFlag(writer, ver_flag);
    }

    try writer.writeByte('\n');
}

pub fn printVer(
    writer: std.fs.File.Writer,
    name: []const u8,
    comptime p: ParseParams,
) !void {
    if (p.ver.len == 0) return;
    try writer.print("{s} (version {s})\n", .{ name, p.ver });
}

pub fn printFlag(writer: std.fs.File.Writer, comptime flag: Flag) !void {
    const indent_str = if (flag.required) indent_required else indent;
    try writer.print("{s}", .{indent_str});

    if (flag.short != 0) {
        try writer.print("-{c}, ", .{flag.short});
    } else try writer.print("    ", .{});

    try writer.print("--{s}", .{flag.long});

    if (flag.usage.len > 0) try writer.print(" {s}", .{flag.usage});

    try writer.print("\n\t{s}\n", .{flag.desc});
}
