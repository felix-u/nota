const Context = @import("Context.zig");
const Procedure = @This();
const std = @import("std");

immediate: ?immediate_fn = null,
address: u32 = undefined,

pub fn putBuiltins(ctx: *Context) !void {
    try ctx.procedures.ensureUnusedCapacity(builtin_fn_names.len);
    inline for (builtin_fn_names) |fn_name| {
        ctx.procedures.putAssumeCapacity(
            fn_name,
            .{ .immediate = @field(Builtins, fn_name) },
        );
    }
}

const immediate_fn = *const fn (ctx: *Context) anyerror!void;

const builtin_fn_names = [_][]const u8{
    "+",
    "-",
    "*",
    "/",
    "dup",
    "end",
    "println",
    "procedure",
};

const Builtins = struct {
    fn @"+"(ctx: *Context) !void {
        const right = try ctx.stack.popType(ctx, .int, isize);
        const left = try ctx.stack.popType(ctx, .int, isize);
        try ctx.stack.push(.{ .int = left + right });
    }

    fn @"-"(ctx: *Context) !void {
        const right = try ctx.stack.popType(ctx, .int, isize);
        const left = try ctx.stack.popType(ctx, .int, isize);
        try ctx.stack.push(.{ .int = left - right });
    }

    fn @"*"(ctx: *Context) !void {
        const right = try ctx.stack.popType(ctx, .int, isize);
        const left = try ctx.stack.popType(ctx, .int, isize);
        try ctx.stack.push(.{ .int = left * right });
    }

    fn @"/"(ctx: *Context) !void {
        const right = try ctx.stack.popType(ctx, .int, isize);
        const left = try ctx.stack.popType(ctx, .int, isize);
        try ctx.stack.push(.{ .int = @divTrunc(left, right) });
    }

    fn dup(ctx: *Context) !void {
        const popped = try ctx.stack.pop(ctx);
        try ctx.stack.push(popped);
        try ctx.stack.push(popped);
    }

    fn end(ctx: *Context) !void {
        const ret_addr = ctx.jump_stack.popOrNull() orelse return ctx.err(
            "jump stack underflow: no return address to jump to",
            .{},
        );
        ctx.tok_i = ret_addr;
    }

    fn println(ctx: *Context) !void {
        const popped = try ctx.stack.pop(ctx);
        switch (popped) {
            .int => |int| try ctx.writer.print("{d}\n", .{int}),
            .string => |string| try ctx.writer.print("{s}\n", .{string}),
        }
    }

    fn procedure(ctx: *Context) !void {
        const i = &ctx.tok_i;
        if (i.* + 2 >= ctx.toks.items.len) {
            return ctx.err("end of file while parsing procedure", .{});
        }

        i.* += 1;
        const address: u32 = @intCast(i.*);
        const proc_name = ctx.lexeme(address);

        i.* += 1;
        while (i.* < ctx.toks.items.len) : (i.* += 1) {
            const lexeme = ctx.lexeme(@intCast(i.*));
            if (std.mem.eql(u8, lexeme, "end")) break;
        } else return ctx.err("end of file while parsing procedure", .{});

        try ctx.procedures.put(proc_name, .{ .address = address });
    }
};
