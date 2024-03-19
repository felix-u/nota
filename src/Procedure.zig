const Context = @import("Context.zig");
const Instruction = @import("Instruction.zig");
const Procedure = @This();
const std = @import("std");

@"comptime": ?comptime_fn = null,
instructions: Instruction.List = undefined,
compiled: ?u32 = null,

pub const Map = std.StringHashMap(@This());
pub const List = std.ArrayList(@This());

pub fn putBuiltins(ctx: *Context) !void {
    try ctx.procedures_map.ensureUnusedCapacity(builtin_fn_names.len);
    inline for (builtin_fn_names) |fn_name| {
        ctx.procedures_map.putAssumeCapacity(
            fn_name,
            .{ .@"comptime" = @field(Builtins, fn_name) },
        );
    }
}

const comptime_fn = *const fn (
    ctx: *Context,
    instructions: Instruction.List,
) anyerror!void;

const builtin_fn_names = blk: {
    const builtin_fns = @typeInfo(Builtins).Struct.decls;
    var fn_names = [_][]const u8{""} ** builtin_fns.len;
    for (builtin_fns, 0..) |builtin_fn, i| {
        fn_names[i] = builtin_fn.name;
    }
    break :blk fn_names;
};

const Builtins = struct {
    pub fn noop(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .noop });
    }

    pub fn @"+"(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .@"+" });
    }

    pub fn @"-"(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .@"-" });
    }

    pub fn @"*"(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .@"*" });
    }

    pub fn @"/"(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .@"/" });
    }

    pub fn @"="(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .@"=" });
    }

    pub fn drop(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .drop });
    }

    pub fn dup(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .dup });
    }

    pub fn exit(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .exit });
    }

    pub fn jump(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .jump });
    }

    pub fn @"jump-relative"(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .@"jump-relative" });
    }

    pub fn @"jump-if-true-relative"(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(
            .{ .operation = .@"jump-if-true-relative" },
        );
    }

    pub fn not(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .not });
    }

    pub fn @"return"(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .@"return" });
    }

    pub fn println(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .println });
    }

    pub fn procedure(ctx: *Context, _: Instruction.List) !void {
        var proc_instructions = Instruction.List.init(ctx.allocator);
        const i = &ctx.tok_i;
        if (i.* + 2 >= ctx.toks.items.len) {
            return ctx.err("end of file while parsing procedure", .{});
        }

        i.* += 1;
        const proc_name = ctx.lexeme(i.*);

        const global_instructions = ctx.instructions;
        ctx.instructions = proc_instructions;
        defer ctx.instructions = global_instructions;

        i.* += 1;
        while (i.* < ctx.toks.items.len) : (i.* += 1) {
            const lexeme = ctx.lexeme(@intCast(i.*));
            if (std.mem.eql(u8, lexeme, "end")) break;
            try Instruction.fromTok(ctx, i.*);
        } else return ctx.err("end of file while parsing procedure", .{});

        proc_instructions = ctx.instructions;
        try proc_instructions.append(.{ .operation = .@"return" });

        try ctx.procedures_map.put(
            proc_name,
            .{ .instructions = proc_instructions },
        );
    }

    pub fn @"push-jumpstack-relative"(
        ctx: *Context,
        _: Instruction.List,
    ) !void {
        try ctx.instructions.append(
            .{ .operation = .@"push-jumpstack-relative" },
        );
    }
};
