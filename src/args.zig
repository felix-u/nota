const std = @import("std");

pub const Error = error{
    InvalidCommand,
    InvalidFlag,
    InvalidUsage,
    MissingArgument,
    MissingCommand,
    MissingFlag,
    UnexpectedArgument,
};

pub fn errMsg(
    comptime e: Error,
    writer: std.fs.File.Writer,
    argv: [][]const u8,
    i: usize,
    char_i: ?usize,
) anyerror {
    _ = try writer.write("error: ");

    switch (e) {
        inline Error.InvalidCommand => try writer.print("no such command '{s}'", .{argv[i]}),
        inline Error.InvalidFlag => {
            _ = try writer.write("no such flag '");
            if (char_i) |c| {
                try writer.writeByte(argv[i][c]);
            } else _ = try writer.write(argv[i]);
            _ = try writer.writeByte('\'');
        },
        inline Error.InvalidUsage => _ = try writer.write("invalid usage"),
        inline Error.MissingArgument => {
            _ = try writer.write("expected positional argument to '");
            if (char_i) |c| {
                try writer.writeByte(argv[i][c]);
            } else _ = try writer.write(argv[i]);
            _ = try writer.writeByte('\'');
        },
        inline Error.MissingCommand => _ = try writer.write("expected command"),
        inline Error.MissingFlag => _ = try writer.write("expected flag"),
        inline Error.UnexpectedArgument => {
            _ = try writer.write("unexpected positional argument '");
            if (char_i) |c| {
                try writer.writeByte(argv[i][c]);
            } else _ = try writer.write(argv[i]);
            _ = try writer.writeByte('\'');
        },
    }

    _ = try writer.writeByte('\n');

    return e;
}

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
    usage: []const u8 = "",
    name: []const u8,

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
    if (argv.len == 1) {
        try printHelp(writer, argv[0], p, null);
        return errMsg(Error.InvalidUsage, writer, argv, 0, null);
    }

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
        inline 1 => if (p.cmds[0].desc.len > 0) {
            @compileError("a command with non-empty .desc implies the existence of several others, \n" ++
                "but there is only 1; use ParseParams.desc");
        },
        inline else => {},
    }

    var arg_kinds = try allocator.alloc(ArgKind, argv.len - 1);
    defer allocator.free(arg_kinds);
    procArgKindList(p, arg_kinds, argv[1..]);

    var got_pos = false;
    var got_cmd = if (p.cmds.len == 1) true else false;

    inline for (p.cmds) |cmd| {
        if (p.cmds.len == 1 or std.mem.eql(u8, argv[1], cmd.name)) {
            @field(result, cmd.name).invoked = true;

            var arg_i: usize = 1;
            cmd_arg: while (arg_i < argv.len) {
                const arg_kind = arg_kinds[arg_i - 1];
                const arg = argv[arg_i];
                switch (arg_kind) {
                    .cmd => if (!got_cmd) {
                        got_cmd = true;
                    },
                    .pos => switch (cmd.kind) {
                        inline .boolean => return errMsg(Error.UnexpectedArgument, writer, argv, arg_i, null),
                        inline .single_pos => {
                            if (got_pos) return errMsg(Error.UnexpectedArgument, writer, argv, arg_i, null);
                            @field(result, cmd.name).pos = arg_i;
                            got_pos = true;
                        },
                        inline .multi_pos => @field(result, cmd.name).pos.appendAssumeCapacity(arg_i),
                    },
                    .pos_marker => {},
                    .short => for (arg[1..], 1..) |short, short_i| {
                        if (short == help_flag.short) {
                            try printHelp(writer, argv[0], p, cmd);
                            return null;
                        }

                        if (cmd.flags.len == 0) return errMsg(Error.InvalidFlag, writer, argv, arg_i, null);

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
                                            arg_kinds[arg_i + 1] != .pos)
                                        {
                                            return errMsg(Error.MissingArgument, writer, argv, arg_i, short_i);
                                        }
                                        arg_i += 1;
                                        @field(@field(result, cmd.name), flag.long) = arg_i;
                                        arg_i += 1;
                                        continue :cmd_arg;
                                    },
                                    inline .multi_pos => {
                                        if (short_i != arg.len - 1 or
                                            arg_i == argv.len - 1 or
                                            arg_kinds[arg_i] != .pos)
                                        {
                                            return errMsg(Error.MissingArgument, writer, argv, arg_i, short_i);
                                        }
                                        arg_i += 1;
                                        while (arg_i < argv.len and arg_kinds[arg_i - 1] == .pos) : (arg_i += 1) {
                                            @field(@field(result, cmd.name), flag.long).appendAssumeCapacity(arg_i);
                                        } else continue :cmd_arg;
                                    },
                                }
                                break :match;
                            }
                        } else return errMsg(Error.InvalidFlag, writer, argv, arg_i, null);
                    },
                    .long => {
                        if (std.mem.eql(u8, arg[2..], help_flag.long)) {
                            try printHelp(writer, argv[0], p, cmd);
                            return null;
                        }

                        if (cmd.flags.len == 0) return errMsg(Error.InvalidFlag, writer, argv, arg_i, null);

                        match: inline for (cmd.flags) |flag| {
                            if (std.mem.eql(u8, arg[2..], flag.long)) {
                                // Matched flag in long form.
                                switch (flag.kind) {
                                    inline .boolean => {
                                        @field(@field(result, cmd.name), flag.long) = true;
                                    },
                                    inline .single_pos => {
                                        if (arg_i == argv.len - 1 or arg_kinds[arg_i + 1] != .pos) {
                                            return errMsg(Error.MissingArgument, writer, argv, arg_i, null);
                                        }
                                        arg_i += 1;
                                        @field(@field(result, cmd.name), flag.long) = arg_i;
                                        arg_i += 1;
                                        continue :cmd_arg;
                                    },
                                    inline .multi_pos => {
                                        if (arg_i == argv.len - 1 or arg_kinds[arg_i] != .pos) {
                                            return errMsg(Error.MissingArgument, writer, argv, arg_i, null);
                                        }
                                        arg_i += 1;
                                        while (arg_i < argv.len and arg_kinds[arg_i - 1] == .pos) : (arg_i += 1) {
                                            @field(@field(result, cmd.name), flag.long).appendAssumeCapacity(arg_i);
                                        } else continue :cmd_arg;
                                    },
                                }
                                break :match;
                            }
                        } else return errMsg(Error.InvalidFlag, writer, argv, arg_i, null);
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
                try printHelp(writer, argv[0], p, cmd);
                const cmd_i = if (p.cmds.len == 1) 0 else 1;
                return errMsg(Error.MissingArgument, writer, argv, cmd_i, null);
            }

            inline for (cmd.flags) |flag| {
                if (flag.required) switch (flag.kind) {
                    inline .boolean => if (@field(@field(result, cmd.name), flag.long) == false) {
                        return errMsg(Error.MissingFlag, writer, argv, 0, null);
                    },
                    inline .single_pos => if (@field(@field(result, cmd.name), flag.long).pos == null) {
                        return errMsg(Error.MissingFlag, writer, argv, 0, null);
                    },
                    inline .multi_pos => if (@field(@field(result, cmd.name), flag.long).items.len == 0) {
                        return errMsg(Error.MissingFlag, writer, argv, 0, null);
                    },
                };
            }

            break;
        }
    } else {
        if (std.mem.eql(u8, argv[1], "--" ++ help_flag.long) or std.mem.eql(u8, argv[1], "-" ++ .{help_flag.short})) {
            try printHelp(writer, argv[0], p, null);
            return null;
        }

        if (std.mem.eql(u8, argv[1], "--" ++ ver_flag.long)) {
            try printVer(writer, argv[0], p);
            return null;
        }

        switch (arg_kinds[0]) {
            .cmd => return errMsg(Error.InvalidCommand, writer, argv, 1, null),
            .pos => unreachable,
            .short, .long, .pos_marker => return errMsg(Error.MissingCommand, writer, argv, 0, null),
        }
    }

    return result;
}

const ArgKind = enum { cmd, pos, short, long, pos_marker };
fn procArgKindList(comptime p: ParseParams, arg_kinds: []ArgKind, argv: []const []const u8) void {
    var only_pos = false;
    var got_cmd = if (p.cmds.len > 1) false else true;

    for (argv, 0..) |arg, i| {
        if (only_pos) {
            arg_kinds[i] = .pos;
        } else if (arg.len == 1) {
            if (!got_cmd) arg_kinds[i] = .cmd;
            arg_kinds[i] = .pos;
        } else if (std.mem.eql(u8, arg, "--")) {
            arg_kinds[i] = .pos_marker;
            only_pos = true;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            arg_kinds[i] = .long;
        } else if (arg[0] == '-') {
            arg_kinds[i] = .short;
        } else if (!got_cmd) {
            got_cmd = true;
            arg_kinds[i] = .cmd;
        } else arg_kinds[i] = .pos;
    }
}

const indent = "  ";
const indent_required = "* ";

pub fn printHelp(
    writer: std.fs.File.Writer,
    name: []const u8,
    comptime p: ParseParams,
    comptime cmd: ?Cmd,
) !void {
    if (cmd == null or p.cmds.len == 1) {
        if (p.desc.len > 0 or p.ver.len > 0) {
            _ = try writer.write(name);
            if (p.desc.len > 0) try writer.print(" - {s}", .{p.desc});
            if (p.ver.len > 0) try writer.print(" (version {s})", .{p.ver});
            try writer.writeByte('\n');
        }

        if (p.usage.len > 0) try writer.print("\nUsage:\n{s}{s} {s}\n", .{ indent, name, p.usage });

        if (p.cmds.len > 1) {
            _ = try writer.write("\nCommands:\n");
            inline for (p.cmds) |subcmd| {
                try printCmd(writer, subcmd);
            }
            _ = try writer.write("\nGeneral options:\n");
            try printFlag(writer, help_flag);
            if (p.ver.len > 0) try printFlag(writer, ver_flag);
        } else {
            _ = try writer.write("\nOptions:\n");

            const all_flags = cmd.?.flags ++ .{help_flag};
            inline for (all_flags) |flag| {
                try printFlag(writer, flag);
            }
        }
    } else {
        if (cmd.?.desc.len > 0) {
            try writer.print("{s} - {s}\n\n", .{ cmd.?.name, cmd.?.desc });
        }

        if (cmd.?.usage.len > 0) {
            try writer.print("Usage:\n{s}{s} {s} {s}\n\n", .{ indent, name, cmd.?.name, cmd.?.usage });
        }

        _ = try writer.write("Options:\n");

        const all_flags = cmd.?.flags ++ .{help_flag};
        inline for (all_flags) |flag| {
            try printFlag(writer, flag);
        }
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

    if (flag.desc.len > 0) try writer.print("\n\t{s}", .{flag.desc});

    _ = try writer.writeByte('\n');
}

pub fn printCmd(writer: std.fs.File.Writer, comptime cmd: Cmd) !void {
    try writer.print("{s}{s}", .{ indent, cmd.name });

    if (cmd.usage.len > 0) try writer.print(" {s}", .{cmd.usage});

    if (cmd.desc.len > 0) try writer.print("\n\t{s}", .{cmd.desc});

    _ = try writer.writeByte('\n');
}
