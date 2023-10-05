const parse = @import("parse.zig");
const std = @import("std.zig");

pub const Node = struct {
    type: u8 = 0,
    child_list_i: u32 = 0,
};

pub const NodeList = std.MultiArrayList(Node);

pub const ChildList = std.ArrayList(u32);
