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

const builtin_fn_names = [_][]const u8{
    "+",
    "-",
    "*",
    "/",
    "dup",
    "println",
    "procedure",
};

const Builtins = struct {
    fn @"+"(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .@"+" });
    }

    fn @"-"(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .@"-" });
    }

    fn @"*"(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .@"*" });
    }

    fn @"/"(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .@"/" });
    }

    fn dup(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .dup });
    }

    fn println(ctx: *Context, _: Instruction.List) !void {
        try ctx.instructions.append(.{ .operation = .println });
    }

    fn procedure(ctx: *Context, _: Instruction.List) !void {
        var proc_instructions = Instruction.List.init(ctx.allocator);
        const i = &ctx.tok_i;
        if (i.* + 2 >= ctx.toks.items.len) {
            return ctx.err("end of file while parsing procedure", .{});
        }

        i.* += 1;
        const proc_name = ctx.lexeme(i.*);

        // TODO: something going wrong here. all procedures are ending up
        // with just the return instruction
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
};
