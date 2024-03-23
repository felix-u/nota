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
            .noop => {},
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
            .@"=" => {
                const right = try ctx.stack.popType(ctx, .int, isize);
                const left = try ctx.stack.popType(ctx, .int, isize);
                try ctx.stack.push(.{ .boolean = (left == right) });
            },
            .drop => {
                _ = try ctx.stack.pop(ctx);
            },
            .dup => {
                const popped = try ctx.stack.pop(ctx);
                try ctx.stack.push(popped);
                try ctx.stack.push(popped);
            },
            .exit => {
                i = @intCast(instructions.len);
                add = 0;
            },
            .jump => {
                i = @intCast(try ctx.stack.popType(ctx, .int, isize));
                add = 0;
            },
            .@"jump-relative" => {
                i += @intCast(try ctx.stack.popType(ctx, .int, isize));
                add = 0;
            },
            .@"jump-if-true" => {
                const jump = try ctx.stack.popType(ctx, .int, isize);
                const popped = try ctx.stack.popType(ctx, .boolean, bool);
                if (!popped) continue;
                i = @intCast(jump);
                add = 0;
            },
            .@"jump-if-true-relative" => {
                const jump = try ctx.stack.popType(ctx, .int, isize);
                const popped = try ctx.stack.popType(ctx, .boolean, bool);
                if (!popped) continue;
                i += @intCast(jump);
                add = 0;
            },
            .not => {
                const popped = try ctx.stack.popType(ctx, .boolean, bool);
                try ctx.stack.push(.{ .boolean = !popped });
            },
            .println => {
                const popped = try ctx.stack.pop(ctx);
                switch (popped) {
                    .none => _ = try ctx.writer.write("<none>\n"),
                    .boolean => |boolean| {
                        try ctx.writer.print("{}\n", .{boolean});
                    },
                    .int => |int| try ctx.writer.print("{d}\n", .{int}),
                    .string => |string| {
                        try ctx.writer.print("{s}\n", .{string});
                    },
                }
            },
            .push => {
                try ctx.stack.push(val);
            },
            .@"push-jumpstack-relative" => {
                const jump = try ctx.stack.popType(ctx, .int, isize);
                try ctx.jump_stack.append(@intCast(i + jump));
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
