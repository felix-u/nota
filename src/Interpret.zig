const Context = @import("Context.zig");
const Instruction = @import("Instruction.zig");
const Procedure = @import("Procedure.zig");
const Stack = @import("Stack.zig");
const std = @import("std");

pub fn all(ctx: *Context) !void {
    ctx.stack = Stack.init(ctx.allocator);
    ctx.jump_stack = std.ArrayList(u32).init(ctx.allocator);

    const instructions = ctx.instruction_stream.items;
    var i: u32 = ctx.instruction_start_point;
    var add: isize = 1;
    while (i < instructions.len) : (i = @intCast(i + add)) {
        add = 1;
        const instruction = instructions[i];
        const val = instruction.operand;
        switch (instruction.operation) {
            .none => {},
            .@"+" => {
                const right = try ctx.stack.popType(ctx, .int, isize);
                const left = try ctx.stack.popType(ctx, .int, isize);
                try ctx.stack.push(.{ .int = left + right });
            },
            .@"-" => {
                const right = try ctx.stack.popType(ctx, .int, isize);
                const left = try ctx.stack.popType(ctx, .int, isize);
                try ctx.stack.push(.{ .int = left - right });
            },
            .@"*" => {
                const right = try ctx.stack.popType(ctx, .int, isize);
                const left = try ctx.stack.popType(ctx, .int, isize);
                try ctx.stack.push(.{ .int = left * right });
            },
            .@"/" => {
                const right = try ctx.stack.popType(ctx, .int, isize);
                const left = try ctx.stack.popType(ctx, .int, isize);
                try ctx.stack.push(.{ .int = @divTrunc(left, right) });
            },
            .dup => {
                const popped = try ctx.stack.pop(ctx);
                try ctx.stack.push(popped);
                try ctx.stack.push(popped);
            },
            .jump => {
                i = @intCast(val.int);
                add = 0;
            },
            .pop => {
                @panic("TODO");
            },
            .println => {
                const popped = try ctx.stack.pop(ctx);
                switch (popped) {
                    .none => _ = try ctx.writer.write("<none>\n"),
                    .int => |int| try ctx.writer.print("{d}\n", .{int}),
                    .string => |string| {
                        try ctx.writer.print("{s}\n", .{string});
                    },
                }
            },
            .push => {
                try ctx.stack.push(val);
            },
            .push_jumpstack => {
                // TODO: why relative? should change instruction name
                try ctx.jump_stack.append(@intCast(i + val.int));
            },
            .@"return" => {
                i = ctx.jump_stack.popOrNull() orelse {
                    return ctx.err(
                        "jump stack underflow: no return address to jump to",
                        .{},
                    );
                };
                add = 0;
            },
        }
    }
}
