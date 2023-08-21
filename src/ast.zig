const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

const Writer = std.fs.File.Writer;

pub const Err = error{
    NoClosingCurly,
    NoNodeName,
    UnmatchedCurlyRight,
};

pub const Node = struct {
    tag: Tag = .root_node,
    data: Data = .{},

    const Data = struct {
        lhs: u32 = 0,
        rhs: u32 = 0,
    };

    const Tag = enum(u8) {
        // lhs unused.
        // rhs is the index into childs_list of the node, or 0 if there are no
        // children.
        root_node,
        // rhs is the index of a string, date, or number.
        // lhs = rhs
        var_decl_literal,
        // rhs is the index of the start of a separately parsed expression.
        // lhs = rhs..
        var_decl_complex,
        // lhs = { }
        // rhs is the index into childs_list of the node, or 0 if there are no
        // children.
        node_decl_simple,
    };
};

pub const NodeList = std.MultiArrayList(Node);

pub const Childs = std.ArrayList(std.ArrayList(u32));

pub fn parseTreeFromToks(
    err_writer: Writer,
    set: *parse.Set,
) !void {
    var childs_i: u32 = 0;
    try parseTreeFromToksRecurse(err_writer, set, 0, &childs_i);
}

pub fn parseTreeFromToksRecurse(
    err_writer: Writer,
    set: *parse.Set,
    depth: u32,
    childs_i: *u32,
) !void {
    const allocator = set.allocator;
    const it = &set.tok_it;

    var tok: ?token.Token = it.peek();

    while (tok) |t| : (tok = it.inc()) switch (t.kind) {
        @intFromEnum(token.Kind.symbol) => {
            if (it.inc()) |t2| switch (t2.kind) {
                '{' => {
                    tok = it.inc();
                    if (tok != null and tok.?.kind != '}') {
                        try recurseInBody(err_writer, set, depth, childs_i);
                    } else {
                        try appendChild(set, depth, childs_i);
                        const node_name_i = it.i - 2;
                        try set.nodes.append(allocator, .{
                            .tag = .node_decl_simple,
                            .data = .{ .lhs = node_name_i, .rhs = 0 },
                        });
                    }
                },
                '=' => {
                    // TODO: Implement properly.
                    tok = it.inc();
                    const var_name_i = it.i - 2;
                    try appendChild(set, depth, childs_i);
                    try set.nodes.append(allocator, .{
                        .tag = .var_decl_literal,
                        .data = .{
                            .lhs = var_name_i,
                            .rhs = it.i,
                        },
                    });
                },
                else => {},
            };
        },
        '{' => {
            return log.reportErr(err_writer, Err.NoNodeName, set, t.beg_i);
        },
        '}' => {
            if (depth != 0) return;
            return log.reportErr(
                err_writer,
                Err.UnmatchedCurlyRight,
                set,
                t.beg_i,
            );
        },
        @intFromEnum(token.Kind.eof) => if (depth != 0) {
            return log.reportErr(err_writer, Err.NoClosingCurly, set, t.beg_i);
        },
        else => {},
    };
}

fn recurseInBody(
    err_writer: Writer,
    set: *parse.Set,
    depth: u32,
    childs_i: *u32,
) anyerror!void {
    const allocator = set.allocator;
    const it = &set.tok_it;

    const node_name_i = it.i - 2;

    try appendChild(set, depth, childs_i);

    const temp_childs_i = childs_i.*;
    childs_i.* = @intCast(set.childs.items.len);

    try set.nodes.append(allocator, .{
        .tag = .node_decl_simple,
        .data = .{ .lhs = node_name_i, .rhs = childs_i.* },
    });

    try parseTreeFromToksRecurse(err_writer, set, depth + 1, childs_i);

    childs_i.* = temp_childs_i;
}

fn appendChild(set: *parse.Set, depth: u32, childs_i: *u32) !void {
    _ = depth;

    if (childs_i.* == set.childs.items.len) try set.childs.append(
        try std.ArrayList(u32).initCapacity(set.allocator, 1),
    );

    var list = &set.childs.items[childs_i.*];
    try list.append(@intCast(set.nodes.len));
}

pub const TokenIterator = struct {
    toks: *std.MultiArrayList(token.Token),
    i: u32,

    const Self = @This();

    pub fn inc(self: *Self) ?token.Token {
        self.i += 1;
        if (self.i == self.toks.len) return null;
        return self.toks.get(self.i);
    }

    pub fn peek(self: *Self) token.Token {
        return self.toks.get(self.i);
    }

    pub fn peekLast(self: *Self) token.Token {
        return if (self.i == 0) .{} else self.toks.get(self.i - 1);
    }

    pub fn peekNext(self: *Self) token.Token {
        if (self.i + 1 == self.toks.len) return .{};
        return self.toks.get(self.i + 1);
    }
};

pub fn printDebugRecurse(
    writer: Writer,
    set: *parse.Set,
    node_i: u32,
    indent_level: u32,
) !void {
    const node = set.nodes.get(node_i);

    try writer.writeByteNTimes('\t', indent_level);
    try writer.print("{any} {any}\n", .{ node.tag, node.data });

    if (node.tag != .root_node and node.data.rhs == 0) return;
    if (node.tag != .root_node and
        node.tag != .node_decl_simple)
    {
        return;
    }
    const childs = set.childs.items[node.data.rhs];

    for (childs.items) |i| {
        try printDebugRecurse(writer, set, i, indent_level + 1);
    }

    // try writer.writeByteNTimes('\t', indent_level);
    // std.debug.print("childs: {any}\n", .{childs.items});

}

pub fn printDebug(writer: Writer, set: *parse.Set) !void {
    _ = try writer.write("NODES:\n");
    var node_i: usize = 0;
    while (node_i < set.nodes.len) : (node_i += 1) {
        try writer.print("{d}\t{any}\n", .{ node_i, set.nodes.get(node_i) });
    }

    try writer.writeByte('\n');

    _ = try writer.write("CHILDS:\n");
    var child_i: usize = 0;
    while (child_i < set.childs.items.len) : (child_i += 1) {
        try writer.print(
            "{d}\t{any}\n",
            .{ child_i, set.childs.items[child_i].items },
        );
    }

    try writer.writeByte('\n');

    _ = try writer.write("TREE:\n");
    try printDebugRecurse(writer, set, 0, 0);
}
