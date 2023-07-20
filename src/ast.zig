const parse = @import("parse.zig");
const std = @import("std");

pub const Node = struct {
    tok_name_i: u32 = undefined,
    expr_beg_i: u32 = undefined,
    expr_end_i: u32 = undefined,
    childs_beg_i: u32 = undefined,
    childs_end_i: u32 = undefined,
};

pub const NodeList = std.MultiArrayList(Node);

pub const Expr = struct {
    beg_i: u32 = undefined,
    end_i: u32 = undefined,
};

pub const ExprList = std.MultiArrayList(Expr);

pub fn fromToksAlloc(allocator: std.mem.Allocator, errWriter: std.fs.File.Writer, set: *parse.Set) !void {
    _ = allocator;
    _ = errWriter;
    _ = set;
    std.debug.print("Unimplemented\n", .{});
}
