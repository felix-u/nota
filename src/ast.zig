const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

const Writer = std.fs.File.Writer;

pub const Err = error{
    FloatingSymbol,
    NoClosingCurly,
    NoNodeName,
    UnexpectedKeyword,
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
        // lhs { }
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
    try parseTreeFromToksRecurse(err_writer, set, 0, 0);
}

pub fn parseTreeFromToksRecurse(
    err_writer: Writer,
    set: *parse.Set,
    depth: u32,
    childs_i: u32,
) !void {
    const allocator = set.allocator;
    const it = &set.tok_it;

    var tok: ?token.Token = it.peek();

    while (tok) |t| : (tok = it.inc()) switch (t.kind) {
        @intFromEnum(token.Kind.symbol) => {
            const keyword = parse.keyword(t.lexeme(set));
            if (keyword == .none) {
                if (it.inc()) |t2| switch (t2.kind) {
                    '{' => {
                        if (keyword != .none) return log.reportErr(
                            err_writer,
                            Err.UnexpectedKeyword,
                            set,
                            t.beg_i,
                        );

                        tok = it.inc();
                        if (tok != null and tok.?.kind != '}') {
                            try recurseInBody(
                                err_writer,
                                set,
                                depth,
                                childs_i,
                            );
                        } else {
                            try appendChild(set, childs_i);
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
                        try appendChild(set, childs_i);
                        try set.nodes.append(allocator, .{
                            .tag = .var_decl_literal,
                            .data = .{ .lhs = var_name_i, .rhs = it.i },
                        });
                    },
                    else => return log.reportErr(
                        err_writer,
                        token.Err.InvalidSyntax,
                        set,
                        t2.beg_i,
                    ),
                };
            } else {
                try parseKeyword(err_writer, set, depth, childs_i, keyword);
            }
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
    childs_i: u32,
) anyerror!void {
    const allocator = set.allocator;
    const it = &set.tok_it;

    const node_name_i = it.i - 2;

    try appendChild(set, childs_i);

    const recurse_childs_i: u32 = @intCast(set.childs.items.len);

    try set.nodes.append(allocator, .{
        .tag = .node_decl_simple,
        .data = .{ .lhs = node_name_i, .rhs = recurse_childs_i },
    });

    try parseTreeFromToksRecurse(err_writer, set, depth + 1, recurse_childs_i);
}

fn appendChild(set: *parse.Set, childs_i: u32) !void {
    if (childs_i == set.childs.items.len) try set.childs.append(
        try std.ArrayList(u32).initCapacity(set.allocator, 1),
    );

    var list = &set.childs.items[childs_i];
    try list.append(@intCast(set.nodes.len));
}

fn parseKeyword(
    err_writer: Writer,
    set: *parse.Set,
    depth: u32,
    childs_i: u32,
    keyword: token.Kind,
) !void {
    _ = err_writer;
    _ = depth;
    _ = childs_i;

    const allocator = set.allocator;
    const it = &set.tok_it;
    _ = allocator;

    var tok: ?token.Token = it.peek();

    switch (keyword) {
        .@"for" => {
            while (tok) |t| : (tok = it.inc()) switch (t.kind) {
                '{' => {},
                else => {},
            };
        },
        else => {
            std.debug.print("UNIMPLEMENTED: {any}\n", .{keyword});
            @panic("UNIMPLEMENTED");
        },
    }
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

pub fn printNicely(writer: Writer, set: *parse.Set) !void {
    try printNicelyRecurse(writer, set, 0, 0, true);
}

pub fn printNicelyRecurse(
    writer: Writer,
    set: *parse.Set,
    node_i: u32,
    indent_level: u32,
    comptime outer_node: bool,
) !void {
    const node = set.nodes.get(node_i);

    if (!outer_node) {
        try writer.writeByteNTimes('\t', indent_level);
        switch (node.tag) {
            .root_node => unreachable,
            .var_decl_literal => {
                const var_name = set.toks.get(node.data.lhs).lexeme(set);
                const literal = set.toks.get(node.data.rhs).lexeme(set);
                try writer.print("{s} = {s}\n", .{ var_name, literal });
                return;
            },
            .node_decl_simple => {
                const node_name = set.toks.get(node.data.lhs).lexeme(set);
                try writer.print("{s} {{\n", .{node_name});
            },
        }
    }

    if (node.tag != .root_node and node.data.rhs == 0) {
        try writer.writeByteNTimes('\t', indent_level);
        _ = try writer.write("}\n");
        return;
    }

    if (node.tag != .root_node and
        node.tag != .node_decl_simple)
    {
        return;
    }

    const childs = set.childs.items[node.data.rhs];

    const childs_indent_level =
        if (outer_node) indent_level else indent_level + 1;

    for (childs.items) |i| {
        try printNicelyRecurse(writer, set, i, childs_indent_level, false);
    }

    switch (node.tag) {
        .node_decl_simple => {
            try writer.writeByteNTimes('\t', indent_level);
            _ = try writer.write("}\n");
        },
        else => {},
    }
}
