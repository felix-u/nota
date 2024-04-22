const std = @import("std");

allocator: std.mem.Allocator,
writer: std.fs.File.Writer,
err_writer: std.fs.File.Writer,

pub fn init(ctx: @This()) @This() {
    return ctx;
}
