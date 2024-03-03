const FilePosition = @import("FilePosition.zig");
const Context = @import("Context.zig");
const std = @import("std");

kind: Kind,
beg_i: u32 = 0,
end_i: u32 = 0,

pub const Kind = enum(u8) { number, symbol };

pub fn lexBytes(ctx: *Context) !void {
    ctx.bytes_it = (try std.unicode.Utf8View.init(ctx.bytes)).iterator();
    ctx.toks = try std.ArrayList(@This()).initCapacity(
        ctx.allocator,
        ctx.bytes.len,
    );

    const it = &ctx.bytes_it;
    var last_i = it.i;
    while (it.nextCodepoint()) |c1| : (last_i = it.i) switch (c1) {
        '\r', '\t', ' ', '\n' => continue,
        '0'...'9' => {
            const beg_i: u32 = @intCast(last_i);
            while (it.nextCodepoint()) |c2| : (last_i = it.i) switch (c2) {
                '\r', '\t', ' ', '\n' => break,
                else => continue,
            };
            it.i -= 1;
            ctx.toks.appendAssumeCapacity(
                .{ .beg_i = beg_i, .end_i = @intCast(it.i), .kind = .number },
            );
        },
        else => {
            const beg_i: u32 = @intCast(last_i);
            while (it.nextCodepoint()) |c2| : (last_i = it.i) switch (c2) {
                '\r', '\t', ' ', '\n' => break,
                else => continue,
            };
            it.i -= 1;
            ctx.toks.appendAssumeCapacity(
                .{ .beg_i = beg_i, .end_i = @intCast(it.i), .kind = .symbol },
            );
        },
    };
}

pub fn printAll(ctx: *Context) !void {
    _ = try ctx.writer.write("Tokens:\n");
    for (ctx.toks.items, 0..ctx.toks.items.len) |tok, i| {
        const pos = FilePosition.fromByteIndex(ctx.bytes, tok.beg_i);
        try ctx.writer.print(
            "{d}:{d}\t{d}\t{s}\t{any}\n",
            .{ pos.row, pos.col, i, ctx.lexeme(@intCast(i)), tok },
        );
    }
}
