const std = @import("std");

pub const Error = error{
    InvalidArgument,
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
    short: ?u8 = null,
    long: []const u8,
    desc: []const u8,
    kind: Kind = .boolean,
    pos_type: []const u8 = "",
    required: bool = false,

    fn resultType(comptime self: *const @This()) type {
        return switch (self.kind) {
            inline .boolean => bool,
            inline .single_pos => if (self.required) usize else ?usize,
            inline .multi_pos => std.ArrayList(usize),
        };
    }
};

pub const Cmd = struct {
    name: ?[]const u8 = null,
    desc: ?[]const u8 = null,
    kind: Kind = .boolean,
    flags: ?[]const Flag = null,

    fn resultType(comptime self: *const @This()) type {
        if (self.flags == null) return switch (self.kind) {
            inline .boolean => bool,
            inline .single_pos => usize,
            inline .multi_pos => std.ArrayList(usize),
        };
        comptime var fields: [self.flags.?.len + 1]std.builtin.Type.StructField = undefined;
        fields[0] = .{
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
        inline for (fields[1..], self.flags.?) |*field, flag| {
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
    .short = 'h',
    .long = "help",
    .desc = "Print this help and exit",
};

pub const ver_flag = Flag{
    .long = "version",
    .desc = "Print version information and exit",
};

pub const ParseParams = struct {
    desc: ?[]const u8 = null,
    ver: ?[]const u8 = null,
    cmds: []const Cmd = &.{.{}},
};

pub fn parseAlloc(
    allocator: std.mem.Allocator,
    writer: std.fs.File.Writer,
    argv: [][]const u8,
    comptime p: ParseParams,
) !?*Cmd.listResultType(p.cmds) {
    var requested_help = false;
    var requested_ver = false;

    const Result = Cmd.listResultType(p.cmds);
    var result = try allocator.create(Result);
    errdefer allocator.destroy(result);

    inline for (@typeInfo(Result).Struct.fields, 0..) |_, idx| {
        const cmd = p.cmds[idx];
        const cmd_name = cmd.name orelse "no_command";
        if (cmd.kind == .multi_pos or cmd.kind == .multi_pos) {
            @field(result, cmd_name) = std.ArrayList(usize).init(allocator);
            @field(result, cmd_name).ensureTotalCapacity(argv.len);
        }
        if (cmd.flags == null) continue;
        inline for (cmd.flags.?) |flag| {
            if (flag.kind == .multi_pos or flag.kind == .multi_pos) {
                @field(@field(result, cmd_name), flag.long) = std.ArrayList(usize).init(allocator);
                try @field(@field(result, cmd_name), flag.long).ensureTotalCapacity(argv.len);
            }
        }
    }

    var arg_kind_list = try allocator.alloc(ArgKind, argv.len);
    defer allocator.free(arg_kind_list);

    // Error case: `cmds` is an empty slice.
    if (p.cmds.len == 0) @compileError("at least one command must be provided");

    // Error case: a command with .name = null is the root command - the binary itself, with no subcommands.
    // There cannot be other commands.
    if (p.cmds.len > 1) {
        inline for (p.cmds) |cmd| {
            if (cmd.name == null or cmd.desc == null) {
                @compileError("a command with .name = null or .desc = null indicates an" ++
                    " absence of subcommands and must be the only command");
            }
        }
    }

    // Error case: there is 1 command only, and it is named. Why? This should be the root command, with .name = null.
    if (p.cmds.len == 1 and p.cmds[0].name != null) {
        @compileError("a named command implies the existence of several others, but there is only 1;\n" ++
            "leave .name = null");
    }

    // Error case: the root command has a description. The `description` passed to parse() should be used instead.
    if (p.cmds[0].name == null and p.cmds[0].desc != null) {
        @compileError("the root command takes no description; " ++
            "use ParseParams.desc instead and leave command.desc = null");
    }

    // Runtime

    const add_flags = if (p.ver != null) .{ help_flag, ver_flag } else .{help_flag};
    const general_flags = if (p.cmds.len > 1) add_flags else (p.cmds[0].flags orelse .{}) ++ add_flags;
    _ = general_flags;

    if (p.cmds.len == 1) {
        const cmd = p.cmds[0];
        procArgKindList(&arg_kind_list, argv);
        var got_pos = false;
        var arg_idx: usize = 1;
        cmd_arg: while (arg_idx < argv.len) {
            const arg_kind = arg_kind_list[arg_idx];
            const arg = argv[arg_idx];
            switch (arg_kind) {
                .command => unreachable,
                .positional => {
                    switch (cmd.kind) {
                        inline .boolean => return Error.UnexpectedArgument,
                        inline .single_pos => {
                            if (got_pos) return Error.UnexpectedArgument;
                            result.no_command.pos = arg_idx;
                            got_pos = true;
                        },
                        inline .multi_pos => {
                            result.no_command.pos.appendAssumeCapacity(arg_idx);
                            got_pos = true;
                        },
                    }
                },
                .positional_marker => {},
                .short_flag => {
                    for (arg[1..], 1..) |short, short_idx| {
                        if (short == help_flag.short) {
                            requested_help = true;
                            continue;
                        }
                        if (cmd.flags == null) return Error.InvalidFlag;
                        match: inline for (cmd.flags.?) |flag| {
                            // Matched flag in short form.
                            if (flag.short != null and flag.short.? == short) {
                                switch (flag.kind) {
                                    inline .boolean => {
                                        @field(result.no_command, flag.long) = true;
                                    },
                                    inline .single_pos => {
                                        if (short_idx != arg.len - 1 or
                                            arg_idx == argv.len - 1 or
                                            arg_kind_list[arg_idx + 1] != .positional)
                                        {
                                            return Error.MissingArgument;
                                        }
                                        arg_idx += 1;
                                        @field(result.no_command, flag.long) = arg_idx;
                                        arg_idx += 1;
                                        continue :cmd_arg;
                                    },
                                    inline .multi_pos => {
                                        if (short_idx != arg.len - 1 or
                                            arg_idx == argv.len - 1 or
                                            arg_kind_list[arg_idx + 1] != .positional)
                                        {
                                            return Error.MissingArgument;
                                        }
                                        arg_idx += 1;
                                        while (arg_idx < argv.len and arg_kind_list[arg_idx] == .positional) : (arg_idx += 1) {
                                            @field(result.no_command, flag.long).appendAssumeCapacity(arg_idx);
                                        } else continue :cmd_arg;
                                    },
                                }
                                break :match;
                            }
                        } else return Error.InvalidFlag;
                    }
                },
                .long_flag => {
                    if (std.mem.eql(u8, arg[2..], help_flag.long)) {
                        requested_help = true;
                        continue :cmd_arg;
                    }
                    if (p.ver != null and std.mem.eql(u8, arg[2..], ver_flag.long)) {
                        requested_ver = true;
                        continue :cmd_arg;
                    }
                    if (cmd.flags == null) return Error.InvalidFlag;
                    match: inline for (cmd.flags.?) |flag| {
                        if (std.mem.eql(u8, arg[2..], flag.long)) {
                            // Matched flag in long form.
                            switch (flag.kind) {
                                inline .boolean => {
                                    @field(result.no_command, flag.long) = true;
                                },
                                inline .single_pos => {
                                    if (arg_idx == argv.len - 1 or arg_kind_list[arg_idx + 1] != .positional) {
                                        return Error.MissingArgument;
                                    }
                                    arg_idx += 1;
                                    @field(result.no_command, flag.long) = arg_idx;
                                    arg_idx += 1;
                                    continue :cmd_arg;
                                },
                                inline .multi_pos => {
                                    if (arg_idx == argv.len - 1 or arg_kind_list[arg_idx + 1] != .positional) {
                                        return Error.MissingArgument;
                                    }
                                    arg_idx += 1;
                                    while (arg_idx < argv.len and arg_kind_list[arg_idx] == .positional) : (arg_idx += 1) {
                                        @field(result.no_command, flag.long).appendAssumeCapacity(arg_idx);
                                    } else continue :cmd_arg;
                                },
                            }
                            break :match;
                        }
                    } else return Error.InvalidFlag;
                    arg_idx += 1;
                    continue :cmd_arg;
                },
            }
            arg_idx += 1;
            continue :cmd_arg;
        } // :cmd_arg
        if (requested_help) {
            try printHelp(writer, argv[0], p);
            return null;
        }
        if (requested_ver) {
            try printVersion(writer, argv[0], p);
            return null;
        }
        switch (cmd.kind) {
            inline .boolean => {},
            inline .single_pos, .multi_pos => if (!got_pos) {
                try printHelp(writer, argv[0], p);
                return Error.MissingArgument;
            },
        }
    }

    // Case: binary expected arguments but got none.
    if (p.cmds.len == 1 and @intFromEnum(p.cmds[0].kind) > @intFromEnum(Kind.boolean) and argv.len == 1) {
        try printHelp(writer, argv[0], p);
        return Error.MissingArgument;
    }

    return result;
}

const ArgKind = enum { command, positional, positional_marker, short_flag, long_flag };
fn procArgKindList(arg_kind_list: *[]ArgKind, argv: []const []const u8) void {
    var list = arg_kind_list.*;
    var only_poss = false;
    var got_command = false;
    for (argv, 0..) |arg, idx| {
        if (only_poss) {
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
            only_poss = true;
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
    _ = try writer.write(name);
    if (p.desc) |desc| try writer.print(" - {s}", .{desc});
    if (p.ver) |ver| try writer.print(" (version {s})", .{ver});
    try writer.writeByte('\n');

    try writer.print("\nUSAGE:\n{s}{s}", .{ indent, name });
    if (p.cmds.len > 1) _ = try writer.write(" <command>");

    comptime var brackets = "[]";

    comptime var max_pos_cmd_requires = @intFromEnum(Kind.boolean);
    inline for (p.cmds) |cmd| {
        if (@intFromEnum(cmd.kind) > max_pos_cmd_requires) max_pos_cmd_requires = @intFromEnum(cmd.kind);
        brackets = "<>";
    }
    if (max_pos_cmd_requires > @intFromEnum(Kind.boolean)) try writer.print(" {c}arg{c}", .{ brackets[0], brackets[1] });
    if (max_pos_cmd_requires > @intFromEnum(Kind.single_pos)) _ = try writer.write("...");

    comptime var max_flag_num = 0;
    brackets = "[]";
    inline for (p.cmds) |cmd| {
        if (cmd.flags) |flags| {
            if (flags.len > max_flag_num) max_flag_num = flags.len;
            inline for (flags) |_| {
                brackets = "<>";
            }
        }
    }
    if (max_flag_num > 0) try writer.print(" {c}option{c}", .{ brackets[0], brackets[1] });
    if (max_flag_num > 1) _ = try writer.write("...");

    comptime var max_pos_expected = @intFromEnum(Kind.boolean);
    inline for (p.cmds) |cmd| {
        if (cmd.flags) |flags| {
            inline for (flags) |flag| {
                if (@intFromEnum(flag.kind) > max_pos_expected) max_pos_expected = @intFromEnum(flag.kind);
            }
        }
    }
    if (max_pos_expected > @intFromEnum(Kind.boolean)) try writer.print(" {c}arg{c}", .{ brackets[0], brackets[1] });
    if (max_pos_expected > @intFromEnum(Kind.single_pos)) _ = try writer.write("...");

    try writer.writeByte('\n');

    if (p.cmds.len == 1 and p.cmds[0].flags != null) {
        _ = try writer.write("\nOPTIONS:\n");
        const all_flags = p.cmds[0].flags.? ++ (if (p.ver != null) .{ help_flag, ver_flag } else .{help_flag});
        inline for (all_flags) |flag| {
            try printFlag(writer, flag);
        }
    } else {
        _ = try writer.write("\nCOMMANDS:\n");
        inline for (p.cmds) |cmd| {
            if (cmd.name != null) try writer.print("{s}{s}\t\t{s}\n", .{ indent, cmd.name.?, cmd.desc.? });
        }
        _ = try writer.write("\nGENERAL OPTIONS:\n");
        try printFlag(writer, help_flag);
        if (p.ver != null) try printFlag(writer, ver_flag);
    }

    try writer.writeByte('\n');
}

pub fn printVersion(
    writer: std.fs.File.Writer,
    name: []const u8,
    comptime p: ParseParams,
) !void {
    if (p.ver == null) return;
    try writer.print("{s}", .{name});
    try writer.print(" (version {s})", .{p.ver.?});
    try writer.print("\n", .{});
}

pub fn printFlag(writer: std.fs.File.Writer, comptime flag: Flag) !void {
    const indent_str = if (flag.required) indent_required else indent;
    try writer.print("{s}", .{indent_str});

    if (flag.short) |char| {
        try writer.print("-{c}, ", .{char});
    } else try writer.print("    ", .{});

    try writer.print("--{s}", .{flag.long});

    if (@intFromEnum(flag.kind) > @intFromEnum(Kind.boolean)) {
        const pos_type = if (flag.positional_type != null) flag.positional_type.? else "arg";
        const maybe_ellipses = if (@intFromEnum(flag.kind) > @intFromEnum(Kind.single_pos)) "..." else "";
        try writer.print(" <{s}>{s}", .{ pos_type, maybe_ellipses });
    }

    try writer.print("\n", .{});

    try writer.print("\t{s}\n", .{flag.desc});
}
