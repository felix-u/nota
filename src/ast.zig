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

pub const NodeMap = std.StringHashMap(std.ArrayList(u32));

pub const Node = struct {
    decls: std.ArrayList(u32) = undefined,
    childs: std.ArrayList(u32) = undefined,
};

pub const Decl = struct {
    tok_name_i: u32 = undefined,
    expr_i: u32 = undefined,
};

pub const Expr = struct {
    tok_beg_i: u32 = undefined,
    tok_end_i: u32 = undefined,
};

pub fn parseToks(
    err_writer: Writer,
    set: *parse.Set,
    comptime in_body: bool,
) !void {
    var it = set.tok_it;

    var tok: ?token.Token = it.peek();

    while (tok) |t| : (tok = it.inc()) switch (t.kind) {
        .symbol => if (it.inc()) |t2| switch (t2.kind) {
            .curly_left => {
                tok = it.inc();
                try recurseInBody(err_writer, set);
            },
            .equals => {
                // TODO: Parse decl and expression.
                tok = it.inc();
            },
            else => {},
        },
        .curly_left => {
            return log.reportErr(err_writer, Err.NoNodeName, set, t.beg_i);
        },
        .curly_right => {
            if (in_body) return;
            return log.reportErr(
                err_writer,
                Err.UnmatchedCurlyRight,
                set,
                t.beg_i,
            );
        },
        .eof => if (in_body) {
            return log.reportErr(err_writer, Err.NoClosingCurly, set, t.beg_i);
        },
        else => {},
    };
}

fn recurseInBody(err_writer: Writer, set: *parse.Set) anyerror!void {
    const name_tok = set.toks.get(set.tok_it.i - 2);
    const name = name_tok.lexeme(set);

    const node_i: u32 = @intCast(set.nodes.len);
    try set.nodes.append(set.allocator, .{});

    const name_nodes = (try set.node_map.getOrPut(name)).value_ptr;
    try name_nodes.append(node_i);

    try parseToks(err_writer, set, true);
}

pub const TokenIterator = struct {
    toks: *const std.MultiArrayList(token.Token) = undefined,
    i: u32 = 0,

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
        // const node = set.nodes.get(node_i.*);
        // const name_tok = set.toks.get(node.tok_name_i);
        // const name = set.buf[name_tok.beg_i..name_tok.end_i];

        // _ = try writer.writeByteNTimes('\t', indent);
        // try writer.print("node {d}: {s}\n", .{ node_i.*, name });

        // _ = try writer.writeByteNTimes('\t', indent);
        // try writer.print("{}\n", .{node});

        // try printDebug(writer, set, indent + 1, node_i);
    }

    node_i.* -= 1;
}
