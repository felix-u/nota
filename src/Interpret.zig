const Context = @import("Context.zig");
const Procedure = @import("Procedure.zig");
const Stack = @import("Stack.zig");
const std = @import("std");

pub fn fromToks(ctx: *Context) !void {
    ctx.stack = Stack.init(ctx.allocator);
    ctx.jump_stack = std.ArrayList(u32).init(ctx.allocator);
    ctx.procedures = std.StringHashMap(Procedure).init(ctx.allocator);
    try Procedure.putBuiltins(ctx);

    const i = &ctx.tok_i;

    i.* = 0;
    while (i.* < ctx.toks.items.len) : (i.* += 1) {
        const tok = ctx.toks.items[i.*];
        const lexeme = ctx.lexeme(@intCast(i.*));
        switch (tok.kind) {
            .number => {
                const value =
                    try std.fmt.parseInt(isize, lexeme, 0);
                try ctx.stack.push(.{ .int = value });
            },
            .string => try ctx.stack.push(.{ .string = lexeme }),
            .symbol => {
                const procedure = ctx.procedures.get(lexeme) orelse {
                    return ctx.err("no such procedure '{s}'", .{lexeme});
                };
                if (procedure.immediate) |immediate_fn| {
                    try immediate_fn(ctx);
                } else {
                    try ctx.jump_stack.append(i.*);
                    i.* = procedure.address;
                }
            },
        }
    }
}
