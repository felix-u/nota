const Context = @import("Context.zig");
const std = @import("std");

pub fn fromToks(ctx: *Context) !void {
    ctx.stack = std.ArrayList(isize).init(ctx.allocator);
    ctx.return_stack = std.ArrayList(u32).init(ctx.allocator);
    ctx.procedures = std.StringHashMap(u32).init(ctx.allocator);
    const i = &ctx.tok_i;

    i.* = 0;
    while (i.* < ctx.toks.items.len) : (i.* += 1) {
        const tok = ctx.toks.items[i.*];
        const lexeme = ctx.lexeme(@intCast(i.*));
        switch (tok.kind) {
            .number => {
                const value =
                    try std.fmt.parseInt(isize, lexeme, 0);
                try ctx.stack.append(value);
            },
            .symbol => {
                const procedure = ctx.procedures.get(lexeme) orelse {
                    return ctx.err("no such procedure '{s}'", .{lexeme});
                };
                _ = procedure;
            },
        }
    }
}
