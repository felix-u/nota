const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

pub const Err = error{
    NoNodeName,
};

pub const Node = struct {
    tok_name_i: u32 = undefined,
    expr_beg_i: u32 = undefined,
    expr_end_i: u32 = undefined,
    childs_beg_i: u32 = undefined,
    childs_end_i: u32 = undefined,
};

pub const Expr = struct {
    beg_i: u32 = undefined,
    end_i: u32 = undefined,
};

pub fn fromToksAlloc(allocator: std.mem.Allocator, errWriter: std.fs.File.Writer, set: *parse.Set) !void {
    const it = &set.tok_it;
    it.toks = &set.toks;

    var tok: ?token.Token = it.peek();

    toks: while (tok) |t| : (tok = it.inc()) {
        switch (t.kind) {
            .curly_left => {
                if (it.peekLast().kind != .symbol) return log.reportErr(errWriter, Err.NoNodeName, set, t.beg_i);

                const node_to_fix_i = set.nodes.len;
                try set.nodes.append(allocator, .{
                    .tok_name_i = it.i - 1,
                    .expr_beg_i = @intCast(set.exprs.len),
                    .childs_beg_i = @intCast(set.nodes.len + 1),
                });

                // TODO: Recurse properly.

                tok = it.inc();
                try fromToksAlloc(allocator, errWriter, set);

                set.nodes.items(.expr_end_i)[node_to_fix_i] = @intCast(set.exprs.len);
                set.nodes.items(.childs_end_i)[node_to_fix_i] = @intCast(set.nodes.len);
            },
            .curly_right => return,
            else => {},
        }
        continue :toks;
    }
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
        return if (self.i + 1 == self.toks.len) .{} else self.toks.get(self.i + 1);
    }
};

pub fn printDebug(writer: std.fs.File.Writer, set: *parse.Set, indent: u32, node_i: *u32) !void {
    const childs_end_i = set.nodes.items(.childs_end_i)[node_i.*];
    node_i.* += 1;

    while (node_i.* < childs_end_i) : (node_i.* += 1) {
        const node = set.nodes.get(node_i.*);
        const name_tok = set.toks.get(node.tok_name_i);
        const name = set.buf[name_tok.beg_i..name_tok.end_i];

        _ = try writer.writeByteNTimes('\t', indent);
        try writer.print("{d} {s}\n", .{ node_i.*, name });

        _ = try writer.writeByteNTimes('\t', indent);
        try writer.print("{}\n", .{node});

        try printDebug(writer, set, indent + 1, node_i);
    }

    node_i.* -= 1;
}
