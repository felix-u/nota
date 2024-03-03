const Context = @import("Context.zig");
const std = @import("std");

kind: Kind,
beg_i: u32 = 0,
end_i: u32 = 0,

pub const Kind = enum(u8) { int, symbol };

pub fn lexBytes(ctx: *Context) !void {
    ctx.toks = try std.ArrayList(@This()).initCapacity(
        ctx.allocator,
        ctx.buf.len,
    );

    const it = &ctx.buf_it;
    var last_i = it.i;
    while (it.nextCodepoint()) |c1| : (last_i = it.i) switch (c1) {
        '\r', '\t', ' ', '\n' => continue,
        else => {
            const beg_i: u32 = @intCast(last_i);
            while (it.nextCodepoint()) |c2| : (last_i = it.i) switch (c2) {
                '\r', '\t', ' ', '\n' => break,
                else => continue,
            };
            ctx.toks.appendAssumeCapacity(
                .{ .beg_i = beg_i, .end_i = @intCast(it.i), .kind = .symbol },
            );
        },
    };
}
