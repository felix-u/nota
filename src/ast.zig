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
        // ignore lhs and rhs
        root_node,
        // lhs is name
        var_decl,
        // lhs is name
        node_decl,
    };
};

pub const NodeList = std.MultiArrayList(Node);

pub fn parseToks(
    err_writer: Writer,
    set: *parse.Set,
    comptime in_body: bool,
) !void {
    const it = &set.tok_it;

    var tok: ?token.Token = it.peek();

    while (tok) |t| : (tok = it.inc()) switch (t.kind) {
        @intFromEnum(token.Kind.symbol) => {
            if (it.inc()) |t2| switch (t2.kind) {
                '{' => {
                    tok = it.inc();
                    try recurseInBody(err_writer, set);
                },
                '=' => {
                    // TODO: Parse decl and expression.
                    tok = it.inc();
                },
                else => {},
            };
        },
        '{' => {
            return log.reportErr(err_writer, Err.NoNodeName, set, t.beg_i);
        },
        '}' => {
            if (in_body) return;
            return log.reportErr(
                err_writer,
                Err.UnmatchedCurlyRight,
                set,
                t.beg_i,
            );
        },
        @intFromEnum(token.Kind.eof) => if (in_body) {
            return log.reportErr(err_writer, Err.NoClosingCurly, set, t.beg_i);
        },
        else => {},
    };
}

fn recurseInBody(err_writer: Writer, set: *parse.Set) anyerror!void {
    const allocator = set.allocator;
    const it = &set.tok_it;

    const node_name_i = it.i - 2;

    try set.nodes.append(allocator, .{
        .tag = .node_decl,
        .data = .{
            .lhs = node_name_i,
        },
    });

    try parseToks(err_writer, set, true);
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

pub fn printDebug(
    writer: Writer,
    set: *parse.Set,
    node_i: *u32,
) !void {
    node_i.* += 1;

    while (node_i.* < set.nodes.len) : (node_i.* += 1) {
        try writer.print("{any}\n", .{set.nodes.get(node_i.*)});
    }

    node_i.* -= 1;
}
